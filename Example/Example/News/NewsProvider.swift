import Foundation
import OhSnap

struct NewsProvider {
    // Root response structure with a list of articles
    struct NewsResponse: Decodable {
        struct Article: Decodable, Identifiable {
            struct Source: Decodable {
                let id: String?
                let name: String
            }
            var id: String { url.absoluteString }
            let source: Source
            let author: String?
            let title: String
            let description: String?
            let url: URL
            let urlToImage: URL?
            let publishedAt: Date
            let content: String?
        }

        let status: String
        let totalResults: Int
        let articles: [Article]
    }

    static let newsAPIFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    let client: OhSnapClient

    func fetchArticles(query: String = "") async throws -> NewsResponse {
        #error("You need to get your API Key from https://newsapi.org/")
        let apiKey = ""
        let urlString = "https://newsapi.org/v2/top-headlines?country=us&apiKey=\(apiKey)&q=\(query)"

        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        let result = try await URLSession.shared.data(from: url)
        print("result \(result.1)")
        let data = await client.snapshot(result.0, uniqueIdentifier: "NewsProvider")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(Self.newsAPIFormatter)
        return try decoder.decode(NewsResponse.self, from: data)
    }
}
