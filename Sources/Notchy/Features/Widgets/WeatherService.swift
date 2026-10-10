import CoreLocation
import Foundation

@MainActor
final class WeatherService: NSObject, CLLocationManagerDelegate {
    private(set) var snapshot: WeatherSnapshot?
    var onUpdate: (() -> Void)?

    private let manager = CLLocationManager()
    private var location: CLLocation?
    private var fetchedAt: Date?
    private var fetching = false
    private var wanted = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyReduced
    }

    func prepare() {
        wanted = true
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        refreshIfStale()
    }

    func refreshIfStale() {
        guard wanted, !fetching else { return }
        if let fetchedAt, Date().timeIntervalSince(fetchedAt) < 1200 { return }
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse: manager.requestLocation()
        default: locateByNetwork()
        }
    }

    private func locateByNetwork() {
        guard !fetching else { return }
        fetching = true
        Task {
            let approximate = await Self.approximateLocation()
            fetching = false
            if let approximate { location = approximate }
            fetch()
        }
    }

    private static func approximateLocation() async -> CLLocation? {
        guard let url = URL(string: "https://get.geojs.io/v1/ip/geo.json"),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let lat = (json["latitude"] as? String).flatMap(Double.init),
              let lon = (json["longitude"] as? String).flatMap(Double.init) else { return nil }
        return CLLocation(latitude: lat, longitude: lon)
    }

    private func fetch() {
        guard let coordinate = location?.coordinate, !fetching else { return }
        fetching = true
        Task {
            let result = await WeatherSnapshot.load(latitude: coordinate.latitude, longitude: coordinate.longitude)
            fetching = false
            guard let result else { return }
            snapshot = result
            fetchedAt = Date()
            onUpdate?()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                guard self.wanted else { return }
                self.fetchedAt = nil
                self.refreshIfStale()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                self.location = latest
                self.fetch()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                if self.location == nil { self.locateByNetwork() } else { self.fetch() }
            }
        }
    }
}
