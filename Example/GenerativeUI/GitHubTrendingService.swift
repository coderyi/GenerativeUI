import Foundation

// MARK: - Models

struct TrendingRepo {
    let fullName: String
    let description: String?
    let stars: Int
    let language: String?
}

enum TrendingPeriod: String, CaseIterable {
    case week
    case month

    var title: String {
        switch self {
        case .week:  return "本周 Top 5"
        case .month: return "本月 Top 5"
        }
    }

    /// ISO8601 date string for the start of the period.
    var startDate: String {
        let calendar = Calendar.current
        let days = self == .week ? -7 : -30
        let date = calendar.date(byAdding: .day, value: days, to: Date())!
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }
}

enum GitHubTrendingError: LocalizedError {
    case invalidURL
    case requestFailed(statusCode: Int)
    case decodingFailed
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "请求地址无效"
        case .requestFailed(let code):
            return "GitHub API 请求失败 (HTTP \(code))"
        case .decodingFailed:
            return "数据解析失败"
        case .rateLimited:
            return "请求过于频繁，请稍后再试"
        }
    }
}

// MARK: - Service

final class GitHubTrendingService {

    /// Fetches top 5 repos for a given period from GitHub Search API.
    func fetchTrending(period: TrendingPeriod) async throws -> [TrendingRepo] {
        let query = "created:>\(period.startDate)"
        var components = URLComponents(string: "https://api.github.com/search/repositories")!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "sort", value: "stars"),
            URLQueryItem(name: "order", value: "desc"),
            URLQueryItem(name: "per_page", value: "5")
        ]

        guard let url = components.url else {
            throw GitHubTrendingError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw GitHubTrendingError.requestFailed(statusCode: 0)
        }

        if http.statusCode == 403 || http.statusCode == 429 {
            throw GitHubTrendingError.rateLimited
        }

        guard http.statusCode == 200 else {
            throw GitHubTrendingError.requestFailed(statusCode: http.statusCode)
        }

        return try decodeRepos(from: data)
    }

    /// Fetches both week and month data concurrently, returns a ViewSpec JSON string.
    /// If one period fails, the other still renders (failed tab shows empty list).
    /// Throws only when both requests fail.
    func fetchAndBuildSpec() async throws -> String {
        async let weekTask = fetchSafe(period: .week)
        async let monthTask = fetchSafe(period: .month)

        let weekResult = await weekTask
        let monthResult = await monthTask

        // If both failed, throw the first real error
        if weekResult.repos.isEmpty && monthResult.repos.isEmpty {
            throw weekResult.error ?? monthResult.error ?? GitHubTrendingError.decodingFailed
        }

        return buildSpec(weekRepos: weekResult.repos, monthRepos: monthResult.repos)
    }

    /// Wraps fetchTrending to capture the result or error without throwing.
    private func fetchSafe(period: TrendingPeriod) async -> (repos: [TrendingRepo], error: Error?) {
        do {
            let repos = try await fetchTrending(period: period)
            return (repos, nil)
        } catch {
            print("[GitHubTrending] Failed to fetch \(period.rawValue): \(error.localizedDescription)")
            return ([], error)
        }
    }

    // MARK: - JSON Decoding

    private func decodeRepos(from data: Data) throws -> [TrendingRepo] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["items"] as? [[String: Any]] else {
            throw GitHubTrendingError.decodingFailed
        }

        return items.compactMap { item in
            guard let fullName = item["full_name"] as? String,
                  let stars = item["stargazers_count"] as? Int else {
                return nil
            }
            return TrendingRepo(
                fullName: fullName,
                description: item["description"] as? String,
                stars: stars,
                language: item["language"] as? String
            )
        }
    }

    // MARK: - ViewSpec JSON Building

    func buildSpec(weekRepos: [TrendingRepo], monthRepos: [TrendingRepo]) -> String {
        let spec: [String: Any] = [
            "schemaVersion": "0.1",
            "view": [
                "id": "github_trending",
                "state": ["period": "week"],
                "components": [
                    [
                        "id": "header",
                        "type": "text",
                        "props": ["text": "GitHub Trending", "style": "title"]
                    ],
                    [
                        "id": "period_tabs",
                        "type": "tabs",
                        "props": [
                            "binding": "period",
                            "items": [
                                buildTabItem(
                                    id: "week",
                                    title: TrendingPeriod.week.title,
                                    repos: weekRepos,
                                    prefix: "w"
                                ),
                                buildTabItem(
                                    id: "month",
                                    title: TrendingPeriod.month.title,
                                    repos: monthRepos,
                                    prefix: "m"
                                )
                            ]
                        ] as [String: Any]
                    ]
                ] as [[String: Any]]
            ] as [String: Any]
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: spec),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    private func buildTabItem(id: String, title: String, repos: [TrendingRepo], prefix: String) -> [String: Any] {
        let repoComponents: [[String: Any]] = repos.enumerated().map { index, repo in
            buildRepoItem(repo: repo, rank: index + 1, prefix: prefix)
        }

        return [
            "id": id,
            "title": title,
            "children": [
                [
                    "id": "\(prefix)_list",
                    "type": "list",
                    "props": ["showDivider": true, "spacing": 12],
                    "children": repoComponents
                ] as [String: Any]
            ]
        ]
    }

    private func buildRepoItem(repo: TrendingRepo, rank: Int, prefix: String) -> [String: Any] {
        let rid = "\(prefix)_r\(rank)"
        let starsText = "★ \(Self.formatStars(repo.stars))"
        let lang = repo.language ?? "Unknown"
        let metaText = "\(starsText) · \(lang)"

        var children: [[String: Any]] = [
            [
                "id": "\(rid)_header",
                "type": "row",
                "props": ["spacing": 8, "alignment": "top"],
                "children": [
                    ["id": "\(rid)_rank", "type": "text",
                     "props": ["text": "\(rank)", "style": "body"]],
                    ["id": "\(rid)_name", "type": "text",
                     "props": ["text": repo.fullName, "style": "headline"]]
                ]
            ] as [String: Any]
        ]

        if let desc = repo.description, !desc.isEmpty {
            let truncated = desc.count > 80 ? String(desc.prefix(80)) + "..." : desc
            children.append([
                "id": "\(rid)_desc", "type": "text",
                "props": ["text": truncated, "style": "caption"]
            ])
        }

        children.append([
            "id": "\(rid)_meta", "type": "text",
            "props": ["text": metaText, "style": "caption"]
        ])

        return [
            "id": rid,
            "type": "column",
            "props": ["spacing": 4],
            "children": children
        ]
    }

    // MARK: - Formatting

    static func formatStars(_ count: Int) -> String {
        switch count {
        case ..<1_000:
            return "\(count)"
        case 1_000..<10_000:
            return String(format: "%.1fk", Double(count) / 1_000)
        default:
            return "\(count / 1_000)k"
        }
    }
}
