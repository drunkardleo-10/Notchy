import Accelerate
import AudioToolbox
import CoreAudio
import Darwin
import Foundation

final class ProcessAudioCapture {
    private static let fftSize = 1024
    private static let fftLog2n: vDSP_Length = 9
    private static let ringCapacity = 4096
    private static let floorDB: Float = -58
    private static let ceilingDB: Float = -14

    private let lifecycleQueue = DispatchQueue(label: "com.notchy.audioCapture.lifecycle", qos: .userInitiated)
    private let ioQueue = DispatchQueue(label: "com.notchy.audioCapture.io", qos: .userInteractive)
    private let fftQueue = DispatchQueue(label: "com.notchy.audioCapture.fft", qos: .userInitiated)
    private let ringLock = NSLock()
    private let ringBuffer: UnsafeMutablePointer<Float>

    private var processIDs: [pid_t] = []
    private var bundleIdentifiers: [String] = []
    private var tapID: AudioObjectID = kAudioObjectUnknown
    private var aggregateID: AudioDeviceID = 0
    private var ioProcID: AudioDeviceIOProcID?
    private var fftTimer: DispatchSourceTimer?
    private var ringWrite = 0
    private var sampleRate = 48_000.0
    private var bandRanges: [Range<Int>] = []
    private var pinkCompensationDB: [Float] = []
    private let fft: vDSP.FFT<DSPSplitComplex>?
    private let window: [Float]
    private let windowPowerScalar: Float
    private var samples = [Float](repeating: 0, count: fftSize)
    private var windowed = [Float](repeating: 0, count: fftSize)
    private var real = [Float](repeating: 0, count: fftSize / 2)
    private var imaginary = [Float](repeating: 0, count: fftSize / 2)
    private var powers = [Float](repeating: 0, count: fftSize / 2)
    private var smoothing = [Float](repeating: 0, count: AudioVisualizer.barCount)
    private var lastPublished = [Float](repeating: -1, count: AudioVisualizer.barCount)

    init() {
        ringBuffer = .allocate(capacity: Self.ringCapacity)
        ringBuffer.initialize(repeating: 0, count: Self.ringCapacity)
        fft = vDSP.FFT(log2n: Self.fftLog2n, radix: .radix2, ofType: DSPSplitComplex.self)
        window = vDSP.window(ofType: Float.self, usingSequence: .hanningDenormalized,
                             count: Self.fftSize, isHalfWindow: false)
        let windowPower = vDSP.sum(vDSP.multiply(window, window))
        windowPowerScalar = 2 / (Float(Self.fftSize) * windowPower)
        updateBandRanges()
    }

    deinit {
        stopCapture()
        ringBuffer.deinitialize(count: Self.ringCapacity)
        ringBuffer.deallocate()
    }

    func setBundleIdentifiers(_ identifiers: [String]) {
        lifecycleQueue.async { [weak self] in
            guard let self else { return }
            let identifiers = Array(Set(identifiers)).sorted()
            let ids = Self.processIDs(matching: identifiers)
            guard self.bundleIdentifiers != identifiers || self.processIDs != ids else { return }
            self.bundleIdentifiers = identifiers
            self.stopCapture()
            self.processIDs = ids
            guard !ids.isEmpty else { return }
            if #available(macOS 14.2, *) {
                self.startCapture(processIDs: ids)
            }
        }
    }

    @available(macOS 14.2, *)
    private func startCapture(processIDs: [pid_t]) {
        let processObjects = processIDs.compactMap(Self.processObject(for:))
        guard !processObjects.isEmpty else { return }

        let description = CATapDescription(monoMixdownOfProcesses: processObjects)
        description.muteBehavior = .unmuted
        description.isPrivate = true
        description.isExclusive = false

        var newTapID = kAudioObjectUnknown
        guard AudioHardwareCreateProcessTap(description, &newTapID) == noErr,
              newTapID != kAudioObjectUnknown else { return }
        tapID = newTapID

        guard let tapUID = Self.stringProperty(objectID: tapID, selector: kAudioTapPropertyUID) else {
            stopCapture()
            return
        }

        var format = AudioStreamBasicDescription()
        var formatSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        var formatAddress = AudioObjectPropertyAddress(
            mSelector: kAudioTapPropertyFormat,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyData(tapID, &formatAddress, 0, nil, &formatSize, &format) == noErr,
              Self.isSupported(format) else {
            stopCapture()
            return
        }
        if format.mSampleRate > 0 {
            sampleRate = format.mSampleRate
            updateBandRanges()
        }

        let aggregateDescription: [String: Any] = [
            kAudioAggregateDeviceNameKey: "Notchy Audio Visualizer",
            kAudioAggregateDeviceUIDKey: "com.notchy.audioTap.\(UUID().uuidString)",
            kAudioAggregateDeviceMainSubDeviceKey: "",
            kAudioAggregateDeviceIsPrivateKey: 1,
            kAudioAggregateDeviceIsStackedKey: 0,
            kAudioAggregateDeviceTapAutoStartKey: 1,
            kAudioAggregateDeviceTapListKey: [[
                kAudioSubTapUIDKey: tapUID,
                kAudioSubTapDriftCompensationKey: 0
            ]]
        ]
        var newAggregateID: AudioDeviceID = 0
        guard AudioHardwareCreateAggregateDevice(aggregateDescription as CFDictionary, &newAggregateID) == noErr,
              newAggregateID != 0 else {
            stopCapture()
            return
        }
        aggregateID = newAggregateID

        var newIOProc: AudioDeviceIOProcID?
        let ioStatus = AudioDeviceCreateIOProcIDWithBlock(&newIOProc, aggregateID, ioQueue) { [weak self] _, input, _, _, _ in
            self?.append(input)
        }
        guard ioStatus == noErr, let newIOProc else {
            stopCapture()
            return
        }
        ioProcID = newIOProc
        guard AudioDeviceStart(aggregateID, newIOProc) == noErr else {
            stopCapture()
            return
        }

        let timer = DispatchSource.makeTimerSource(queue: fftQueue)
        timer.schedule(deadline: .now(), repeating: .milliseconds(33), leeway: .milliseconds(2))
        timer.setEventHandler { [weak self] in self?.processFFT() }
        fftTimer = timer
        timer.resume()
    }

    private func stopCapture() {
        fftTimer?.cancel()
        fftTimer = nil

        if aggregateID != 0, let ioProcID {
            AudioDeviceStop(aggregateID, ioProcID)
            AudioDeviceDestroyIOProcID(aggregateID, ioProcID)
        }
        ioProcID = nil
        if aggregateID != 0 {
            AudioHardwareDestroyAggregateDevice(aggregateID)
            aggregateID = 0
        }
        if tapID != kAudioObjectUnknown {
            if #available(macOS 14.2, *) {
                AudioHardwareDestroyProcessTap(tapID)
            }
            tapID = kAudioObjectUnknown
        }

        ringLock.lock()
        ringBuffer.update(repeating: 0, count: Self.ringCapacity)
        ringWrite = 0
        ringLock.unlock()
        fftQueue.sync {
            self.smoothing = [Float](repeating: 0, count: AudioVisualizer.barCount)
            self.lastPublished = [Float](repeating: -1, count: AudioVisualizer.barCount)
        }
        Task { @MainActor in AudioVisualizer.shared.publish([Float](repeating: 0, count: AudioVisualizer.barCount)) }
    }

    private func append(_ buffers: UnsafePointer<AudioBufferList>) {
        let mutableBuffers = UnsafeMutablePointer(mutating: buffers)
        let audioBuffers = UnsafeMutableAudioBufferListPointer(mutableBuffers)
        guard let buffer = audioBuffers.first, let data = buffer.mData,
              buffer.mNumberChannels == 1,
              buffer.mDataByteSize % UInt32(MemoryLayout<Float>.size) == 0 else { return }

        let frameCount = Int(buffer.mDataByteSize / UInt32(MemoryLayout<Float>.size))
        guard frameCount > 0 else { return }
        let source = data.assumingMemoryBound(to: Float.self)

        ringLock.lock()
        defer { ringLock.unlock() }
        if frameCount >= Self.ringCapacity {
            memcpy(ringBuffer, source.advanced(by: frameCount - Self.ringCapacity),
                   Self.ringCapacity * MemoryLayout<Float>.size)
            ringWrite = 0
            return
        }

        let countToEnd = min(frameCount, Self.ringCapacity - ringWrite)
        memcpy(ringBuffer.advanced(by: ringWrite), source, countToEnd * MemoryLayout<Float>.size)
        if countToEnd < frameCount {
            memcpy(ringBuffer, source.advanced(by: countToEnd),
                   (frameCount - countToEnd) * MemoryLayout<Float>.size)
        }
        ringWrite = (ringWrite + frameCount) % Self.ringCapacity
    }

    private func processFFT() {
        guard let fft else { return }
        ringLock.lock()
        let start = (ringWrite - Self.fftSize + Self.ringCapacity) % Self.ringCapacity
        samples.withUnsafeMutableBufferPointer { target in
            if start + Self.fftSize <= Self.ringCapacity {
                memcpy(target.baseAddress!, ringBuffer.advanced(by: start), Self.fftSize * MemoryLayout<Float>.size)
            } else {
                let firstCount = Self.ringCapacity - start
                memcpy(target.baseAddress!, ringBuffer.advanced(by: start), firstCount * MemoryLayout<Float>.size)
                memcpy(target.baseAddress!.advanced(by: firstCount), ringBuffer,
                       (Self.fftSize - firstCount) * MemoryLayout<Float>.size)
            }
        }
        ringLock.unlock()

        vDSP.multiply(samples, window, result: &windowed)
        let halfSize = Self.fftSize / 2
        real.withUnsafeMutableBufferPointer { realBuffer in
            imaginary.withUnsafeMutableBufferPointer { imaginaryBuffer in
                var split = DSPSplitComplex(realp: realBuffer.baseAddress!, imagp: imaginaryBuffer.baseAddress!)
                windowed.withUnsafeBufferPointer { windowBuffer in
                    windowBuffer.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: halfSize) { complex in
                        vDSP_ctoz(complex, 2, &split, 1, vDSP_Length(halfSize))
                    }
                }
                fft.forward(input: split, output: &split)
                realBuffer[0] = 0
                imaginaryBuffer[0] = 0
                vDSP.squareMagnitudes(split, result: &powers)
            }
        }
        vDSP.multiply(windowPowerScalar, powers, result: &powers)

        var levels = [Float](repeating: 0, count: AudioVisualizer.barCount)
        for index in levels.indices {
            let range = bandRanges[index]
            guard !range.isEmpty else { continue }
            var sum: Float = 0
            powers.withUnsafeBufferPointer { buffer in
                vDSP_sve(buffer.baseAddress!.advanced(by: range.lowerBound), 1, &sum, vDSP_Length(range.count))
            }
            let meanPower = sum / Float(range.count)
            let decibels = 10 * log10f(max(meanPower, 1e-12)) + pinkCompensationDB[index]
            let normalized = (max(Self.floorDB, min(Self.ceilingDB, decibels)) - Self.floorDB)
                / (Self.ceilingDB - Self.floorDB)
            let safeNormalized = normalized.isFinite ? normalized : 0
            let current = smoothing[index].isFinite ? smoothing[index] : 0
            let decayed = current * 0.86
            smoothing[index] = safeNormalized > decayed ? decayed + (safeNormalized - decayed) * 0.58 : decayed
            levels[index] = max(0, min(1, smoothing[index].isFinite ? smoothing[index] : 0))
        }

        let changed = zip(levels, lastPublished).contains { abs($0 - $1) > 0.002 }
        guard changed else { return }
        lastPublished = levels
        Task { @MainActor in AudioVisualizer.shared.publish(levels) }
    }

    private func updateBandRanges() {
        let halfSize = Self.fftSize / 2
        let nyquist = sampleRate / 2
        let minimumHz = 60.0
        let maximumHz = min(16_000, nyquist - 1)
        guard maximumHz > minimumHz else {
            bandRanges = Array(repeating: 0..<0, count: AudioVisualizer.barCount)
            pinkCompensationDB = Array(repeating: 0, count: AudioVisualizer.barCount)
            return
        }

        let lowerLog = log(minimumHz)
        let upperLog = log(maximumHz)
        let bands = (0..<AudioVisualizer.barCount).map { index -> (Range<Int>, Float) in
            let lowerHz = exp(lowerLog + (upperLog - lowerLog) * Double(index) / Double(AudioVisualizer.barCount))
            let upperHz = exp(lowerLog + (upperLog - lowerLog) * Double(index + 1) / Double(AudioVisualizer.barCount))
            let lowerBin = max(1, Int((lowerHz / nyquist) * Double(halfSize)))
            let upperBin = max(lowerBin + 1, min(halfSize, Int((upperHz / nyquist) * Double(halfSize))))
            let centerHz = sqrt(lowerHz * upperHz)
            let pinkAdjustment = Float(4.5 * log2(centerHz / 1_000))
            return (lowerBin..<upperBin, pinkAdjustment)
        }
        bandRanges = bands.map(\.0)
        pinkCompensationDB = bands.map(\.1)
    }

    private static func processObject(for pid: pid_t) -> AudioObjectID? {
        var processID = pid
        var processObject = kAudioObjectUnknown
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyTranslatePIDToProcessObject,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address,
            UInt32(MemoryLayout<pid_t>.size), &processID, &size, &processObject
        )
        return status == noErr && processObject != kAudioObjectUnknown ? processObject : nil
    }

    private static func processIDs(matching bundleIdentifiers: [String]) -> [pid_t] {
        guard !bundleIdentifiers.isEmpty else { return [] }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyProcessObjectList,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let system = AudioObjectID(kAudioObjectSystemObject)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr, size > 0 else { return [] }
        var objects = [AudioObjectID](repeating: kAudioObjectUnknown,
                                      count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &objects) == noErr else { return [] }

        return Set(objects.compactMap { objectID -> pid_t? in
            guard let bundleID = processBundleIdentifier(objectID: objectID),
                  bundleIdentifiers.contains(where: { bundleID == $0 || bundleID.hasPrefix($0 + ".") }) else {
                return nil
            }
            return processID(objectID: objectID)
        }).sorted()
    }

    private static func processBundleIdentifier(objectID: AudioObjectID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioProcessPropertyBundleID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: CFString?
        var size = UInt32(MemoryLayout<CFString?>.size)
        let status = withUnsafeMutablePointer(to: &value) {
            AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, $0)
        }
        guard status == noErr, let value else { return nil }
        return value as String
    }

    private static func processID(objectID: AudioObjectID) -> pid_t? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioProcessPropertyPID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var pid: pid_t = 0
        var size = UInt32(MemoryLayout<pid_t>.size)
        let status = withUnsafeMutablePointer(to: &pid) {
            AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, $0)
        }
        return status == noErr && pid > 0 ? pid : nil
    }

    @available(macOS 14.2, *)
    private static func stringProperty(objectID: AudioObjectID, selector: AudioObjectPropertySelector) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: CFString?
        var size = UInt32(MemoryLayout<CFString?>.size)
        let status = withUnsafeMutablePointer(to: &value) {
            AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, $0)
        }
        guard status == noErr, let value else { return nil }
        return value as String
    }

    private static func isSupported(_ format: AudioStreamBasicDescription) -> Bool {
        let requiredFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked
        return format.mFormatID == kAudioFormatLinearPCM
            && (format.mFormatFlags & requiredFlags) == requiredFlags
            && (format.mFormatFlags & kAudioFormatFlagIsNonInterleaved) == 0
            && format.mChannelsPerFrame == 1
            && format.mBytesPerFrame == UInt32(MemoryLayout<Float>.size)
            && format.mBitsPerChannel == UInt32(MemoryLayout<Float>.size * 8)
    }
}
