import SwiftUI
import OhSnap
import Firebase

@main
struct ExampleApp: App {
    @State var client: OhSnapClient
    @State var newsViewModel: NewsViewModel

    init() {
        #error("You need to setup your firebase account")
        FirebaseApp.configure()
        
        let client = OhSnapClient(
            defaultMode: .recording,
            restorePrevious: true,
            baseURL: .cachesDirectory.appending(path: "Snapshots"),
            fileManager: .live,
            userDefaults: .live
        )
        client.register(module: "NewsFeed", files: [
            "NewsProvider"
        ])
        client.register(module: "UserFeed", files: [
            "UsersList",
            "UserProfile"
        ])
        let newsProvider = NewsProvider(client: client)
        newsViewModel = .init(provider: newsProvider)
        self.client = client
    }

    var body: some Scene {
        WindowGroup {
            ContentView(client: client, newsViewModel: newsViewModel)
        }
    }
}
