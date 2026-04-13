import Foundation

// MARK: - Data Models

struct WeatherData {
    let cityName: String
    let currentTemp: Double
    let weatherCode: Int
    let humidity: Int
    let windSpeed: Double
    let dailyHigh: Double
    let dailyLow: Double
    let forecast: [DayForecast]
}

struct DayForecast {
    let date: Date
    let weatherCode: Int
    let tempMax: Double
    let tempMin: Double
}

// MARK: - WeatherService

/// Fetches weather data from Open-Meteo (free, no API key required)
/// and builds ViewSpec JSON for rendering in GenerativeUI.
final class WeatherService {

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Public API

    /// Fetches current weather and 3-day forecast for a city.
    func fetch(city: String) async throws -> WeatherData {
        let location = try await geocode(city: city)
        return try await fetchForecast(location: location)
    }

    /// Converts weather data into a ViewSpec JSON string for `runtime.build()`.
    func buildSpec(from data: WeatherData) -> String {
        let desc = Self.weatherDescription(for: data.weatherCode)

        var components: [[String: Any]] = [
            Self.textComponent(id: "city_name", text: data.cityName, style: "headline"),
            Self.textComponent(id: "weather_desc", text: desc, style: "caption"),
            Self.textComponent(id: "current_temp", text: "\(Int(round(data.currentTemp)))\u{00B0}", style: "title"),
            Self.metricsRow(humidity: data.humidity, windSpeed: data.windSpeed,
                            low: data.dailyLow, high: data.dailyHigh),
        ]

        if !data.forecast.isEmpty {
            components.append(Self.forecastSection(data.forecast))
        }

        let spec: [String: Any] = [
            "schemaVersion": "0.1",
            "view": [
                "id": "weather_card",
                "components": components
            ] as [String: Any]
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: spec, options: []),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return ""
        }
        return jsonString
    }

    // MARK: - Geocoding

    private struct GeoLocation {
        let latitude: Double
        let longitude: Double
        let name: String
    }

    private func geocode(city: String) async throws -> GeoLocation {
        guard let encoded = city.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://geocoding-api.open-meteo.com/v1/search?name=\(encoded)&count=1&language=zh") else {
            throw WeatherError.invalidCity(city)
        }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw WeatherError.requestFailed
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let results = json?["results"] as? [[String: Any]],
              let first = results.first,
              let lat = first["latitude"] as? Double,
              let lon = first["longitude"] as? Double else {
            throw WeatherError.cityNotFound(city)
        }

        let name = first["name"] as? String ?? city
        return GeoLocation(latitude: lat, longitude: lon, name: name)
    }

    // MARK: - Forecast

    private func fetchForecast(location: GeoLocation) async throws -> WeatherData {
        let urlString = "https://api.open-meteo.com/v1/forecast"
            + "?latitude=\(location.latitude)"
            + "&longitude=\(location.longitude)"
            + "&current=temperature_2m,weather_code,wind_speed_10m,relative_humidity_2m"
            + "&daily=temperature_2m_max,temperature_2m_min,weather_code"
            + "&forecast_days=4"
            + "&timezone=auto"
            + "&wind_speed_unit=kmh"

        guard let url = URL(string: urlString) else {
            throw WeatherError.requestFailed
        }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw WeatherError.requestFailed
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let current = json?["current"] as? [String: Any],
              let daily = json?["daily"] as? [String: Any] else {
            throw WeatherError.parseFailed
        }

        // Current conditions
        let temp = current["temperature_2m"] as? Double ?? 0
        let code = current["weather_code"] as? Int ?? 0
        let humidity = current["relative_humidity_2m"] as? Int ?? 0
        let wind = current["wind_speed_10m"] as? Double ?? 0

        // Daily arrays
        let dates = daily["time"] as? [String] ?? []
        let maxTemps = daily["temperature_2m_max"] as? [Double] ?? []
        let minTemps = daily["temperature_2m_min"] as? [Double] ?? []
        let codes = daily["weather_code"] as? [Int] ?? []

        // daily[0] = today (used for high/low), daily[1..3] = forecast
        let todayHigh = maxTemps.first ?? 0
        let todayLow = minTemps.first ?? 0

        var forecast: [DayForecast] = []
        let forecastStart = 1
        let forecastEnd = min(dates.count, maxTemps.count, minTemps.count, codes.count)
        for i in forecastStart..<forecastEnd {
            let date = Self.dateParser.date(from: dates[i]) ?? Date()
            forecast.append(DayForecast(
                date: date,
                weatherCode: codes[i],
                tempMax: maxTemps[i],
                tempMin: minTemps[i]
            ))
        }

        return WeatherData(
            cityName: location.name,
            currentTemp: temp,
            weatherCode: code,
            humidity: humidity,
            windSpeed: wind,
            dailyHigh: todayHigh,
            dailyLow: todayLow,
            forecast: forecast
        )
    }

    // MARK: - Date Formatters

    private static let dateParser: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    // MARK: - WMO Weather Code Mapping

    static func weatherDescription(for code: Int) -> String {
        switch code {
        case 0:           return "晴"
        case 1:           return "大部晴朗"
        case 2:           return "多云"
        case 3:           return "阴"
        case 45, 48:      return "雾"
        case 51, 53, 55:  return "毛毛雨"
        case 61, 63, 65:  return "雨"
        case 71, 73, 75:  return "雪"
        case 80, 81, 82:  return "阵雨"
        case 95, 96, 99:  return "雷暴"
        default:          return "未知"
        }
    }

    // MARK: - ViewSpec JSON Builders

    private static func textComponent(id: String, text: String, style: String) -> [String: Any] {
        [
            "id": id,
            "type": "text",
            "props": ["text": text, "style": style] as [String: Any]
        ]
    }

    private static func metricsRow(humidity: Int, windSpeed: Double, low: Double, high: Double) -> [String: Any] {
        [
            "id": "metrics_row",
            "type": "row",
            "props": ["spacing": 16] as [String: Any],
            "children": [
                textComponent(id: "humidity", text: "湿度 \(humidity)%", style: "caption"),
                textComponent(id: "wind", text: "风速 \(Int(round(windSpeed))) km/h", style: "caption"),
                textComponent(id: "range", text: "今日 \(Int(round(low)))\u{00B0}/\(Int(round(high)))\u{00B0}", style: "caption"),
            ]
        ]
    }

    private static let weekdayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "EE"
        return f
    }()

    private static func forecastSection(_ forecast: [DayForecast]) -> [String: Any] {
        let rows: [[String: Any]] = forecast.enumerated().map { index, day in
            let weekday = weekdayFormatter.string(from: day.date)
            let desc = weatherDescription(for: day.weatherCode)
            return [
                "id": "day_\(index + 1)",
                "type": "row",
                "props": ["spacing": 12] as [String: Any],
                "children": [
                    textComponent(id: "d\(index + 1)_weekday", text: weekday, style: "body"),
                    textComponent(id: "d\(index + 1)_desc", text: desc, style: "body"),
                    textComponent(id: "d\(index + 1)_temp",
                                  text: "\(Int(round(day.tempMin)))\u{00B0} / \(Int(round(day.tempMax)))\u{00B0}",
                                  style: "caption"),
                ]
            ]
        }

        return [
            "id": "forecast_section",
            "type": "section",
            "props": ["title": "未来 \(forecast.count) 天"] as [String: Any],
            "children": [
                [
                    "id": "forecast_list",
                    "type": "list",
                    "props": ["showDivider": true] as [String: Any],
                    "children": rows
                ] as [String: Any]
            ]
        ]
    }
}

// MARK: - Errors

enum WeatherError: LocalizedError {
    case invalidCity(String)
    case cityNotFound(String)
    case requestFailed
    case parseFailed

    var errorDescription: String? {
        switch self {
        case .invalidCity(let name):
            return "无效的城市名「\(name)」"
        case .cityNotFound(let name):
            return "未找到城市「\(name)」，请检查城市名"
        case .requestFailed:
            return "天气数据请求失败"
        case .parseFailed:
            return "天气数据解析失败"
        }
    }
}
