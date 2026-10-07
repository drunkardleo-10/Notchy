import AppKit

public final class CGSSpace {
    private let identifier: CGSSpaceID
    private let createdByInit: Bool

    public var windows: Set<NSWindow> = [] {
        didSet {
            let remove = oldValue.subtracting(self.windows)
            let add = self.windows.subtracting(oldValue)

            CGSRemoveWindowsFromSpaces(_CGSDefaultConnection(),
                                       remove.map { $0.windowNumber } as NSArray,
                                       [self.identifier])
            CGSAddWindowsToSpaces(_CGSDefaultConnection(),
                                  add.map { $0.windowNumber } as NSArray,
                                  [self.identifier])
        }
    }

    public init(level: Int = 0) {
        let flag = 0x1
        self.identifier = CGSSpaceCreate(_CGSDefaultConnection(), flag, nil)
        CGSSpaceSetAbsoluteLevel(_CGSDefaultConnection(), self.identifier, level)
        CGSShowSpaces(_CGSDefaultConnection(), [self.identifier])
        self.createdByInit = true
    }

    public init(id: UInt64) {
        self.identifier = id
        CGSShowSpaces(_CGSDefaultConnection(), [self.identifier])
        self.createdByInit = false
    }

    public func show() {
        CGSShowSpaces(_CGSDefaultConnection(), [self.identifier])
    }

    deinit {
        CGSHideSpaces(_CGSDefaultConnection(), [self.identifier])
        if createdByInit {
            CGSSpaceDestroy(_CGSDefaultConnection(), self.identifier)
        }
    }
}

fileprivate typealias CGSConnectionID = UInt
fileprivate typealias CGSSpaceID = UInt64
@_silgen_name("_CGSDefaultConnection")
fileprivate func _CGSDefaultConnection() -> CGSConnectionID
@_silgen_name("CGSSpaceCreate")
fileprivate func CGSSpaceCreate(_ cid: CGSConnectionID, _ unknown: Int, _ options: NSDictionary?) -> CGSSpaceID
@_silgen_name("CGSSpaceDestroy")
fileprivate func CGSSpaceDestroy(_ cid: CGSConnectionID, _ space: CGSSpaceID)
@_silgen_name("CGSSpaceSetAbsoluteLevel")
fileprivate func CGSSpaceSetAbsoluteLevel(_ cid: CGSConnectionID, _ space: CGSSpaceID, _ level: Int)
@_silgen_name("CGSAddWindowsToSpaces")
fileprivate func CGSAddWindowsToSpaces(_ cid: CGSConnectionID, _ windows: NSArray, _ spaces: NSArray)
@_silgen_name("CGSRemoveWindowsFromSpaces")
fileprivate func CGSRemoveWindowsFromSpaces(_ cid: CGSConnectionID, _ windows: NSArray, _ spaces: NSArray)
@_silgen_name("CGSHideSpaces")
fileprivate func CGSHideSpaces(_ cid: CGSConnectionID, _ spaces: NSArray)
@_silgen_name("CGSShowSpaces")
fileprivate func CGSShowSpaces(_ cid: CGSConnectionID, _ spaces: NSArray)
