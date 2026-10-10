import Foundation

struct WeatherSnapshot {
    let temperature: Int
    let code: Int
    let isDay: Bool
    let aqi: Int?
    let sunrises: [Date]
    let sunsets: [Date]

    func nextSunEvent(after date: Date) -> (time: Date, rising: Bool)? {
        (sunrises.map { ($0, true) } + sunsets.map { ($0, false) })
            .filter { $0.0 > date }
            .min { $0.0 < $1.0 }
            .map { (time: $0.0, rising: $0.1) }
    }

    var condition: (symbol: String, label: String) {
        switch code {
        case 0: return (isDay ? "sun.max.fill" : "moon.stars.fill", "Clear")
        case 1, 2: return (isDay ? "cloud.sun.fill" : "cloud.moon.fill", "Partly Cloudy")
        case 3: return ("cloud.fill", "Cloudy")
        case 45, 48: return ("cloud.fog.fill", "Foggy")
        case 51...57: return ("cloud.drizzle.fill", "Drizzle")
        case 61...67, 80...82: return ("cloud.rain.fill", "Rain")
        case 71...77, 85, 86: return ("cloud.snow.fill", "Snow")
        case 95...99: return ("cloud.bolt.rain.fill", "Storms")
        default: return ("cloud.fill", "Cloudy")
        }
    }

    static func airQuality(_ aqi: Int) -> (symbol: String, label: String) {
        switch aqi {
        case ..<51: return ("aqi.low", "Good")
        case ..<101: return ("aqi.medium", "Moderate")
        case ..<151: return ("aqi.medium", "Sensitive")
        case ..<201: return ("aqi.high", "Unhealthy")
        case ..<301: return ("aqi.high", "Very Unhealthy")
        default: return ("aqi.high", "Hazardous")
        }
    }
}

extension WeatherSnapshot {
    static func load(latitude: Double, longitude: Double) async -> WeatherSnapshot? {
        let lat = String(format: "%.2f", latitude), lon = String(format: "%.2f", longitude)
        let unit = Locale.current.measurementSystem == .us ? "fahrenheit" : "celsius"
        var forecast = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        forecast?.queryItems = [
            URLQueryItem(name: "latitude", value: lat), URLQueryItem(name: "longitude", value: lon),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code,is_day"),
            URLQueryItem(name: "daily", value: "sunrise,sunset"),
            URLQueryItem(name: "temperature_unit", value: unit),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "timeformat", value: "unixtime"),
            URLQueryItem(name: "forecast_days", value: "2"),
        ]
        var air = URLComponents(string: "https://air-quality-api.open-meteo.com/v1/air-quality")
        air?.queryItems = [
            URLQueryItem(name: "latitude", value: lat), URLQueryItem(name: "longitude", value: lon),
            URLQueryItem(name: "current", value: "us_aqi"),
            URLQueryItem(name: "timeformat", value: "unixtime"),
        ]
        let forecastURL = forecast?.url, airURL = air?.url
        async let forecastResponse: ForecastResponse? = decode(forecastURL)
        async let airResponse: AirResponse? = decode(airURL)
        guard let weather = await forecastResponse else { return nil }
        let aqi = await airResponse?.current.usAqi
        return WeatherSnapshot(
            temperature: Int(weather.current.temperature.rounded()),
            code: weather.current.weatherCode,
            isDay: weather.current.isDay == 1,
            aqi: aqi.map { Int($0.rounded()) },
            sunrises: weather.daily.sunrise.map(Date.init(timeIntervalSince1970:)),
            sunsets: weather.daily.sunset.map(Date.init(timeIntervalSince1970:))
        )
    }

    private static func decode<T: Decodable>(_ url: URL?) async -> T? {
        guard let url, let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}

private struct ForecastResponse: Decodable {
    struct Current: Decodable {
        let temperature: Double
        let weatherCode: Int
        let isDay: Int

        enum CodingKeys: String, CodingKey {
            case temperature = "temperature_2m"
            case weatherCode = "weather_code"
            case isDay = "is_day"
        }
    }
    struct Daily: Decodable {
        let sunrise: [TimeInterval]
        let sunset: [TimeInterval]
    }
    let current: Current
    let daily: Daily
}

private struct AirResponse: Decodable {
    struct Current: Decodable {
        let usAqi: Double?

        enum CodingKeys: String, CodingKey {
            case usAqi = "us_aqi"
        }
    }
    let current: Current
}
