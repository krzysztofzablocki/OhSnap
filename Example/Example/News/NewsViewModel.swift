import Foundation

@MainActor @Observable
class NewsViewModel {
    var provider: NewsProvider
    var articles: [NewsProvider.NewsResponse.Article] = []
    var error: String?
    var isLoading = false
    var query: String = ""

    init(provider: NewsProvider) {
        self.provider = provider
    }

    func refresh() async {
        error = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await provider.fetchArticles(query: query)
            articles = response.articles
                .filter({
                    !$0.id.contains("removed.com")
                })
                .sorted(by: {
                    $0.publishedAt < $1.publishedAt
                })
        } catch {
            self.error = "Unable to fetch articles \(error.localizedDescription)"
        }
    }
}
