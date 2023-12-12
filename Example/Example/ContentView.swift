import SwiftUI
import OhSnap
import OhSnapFirebase

struct ContentView: View {
    let client: OhSnapClient
    let newsViewModel: NewsViewModel

    var body: some View {
        TabView {
            VStack {
                NewsView(viewModel: newsViewModel)
            }
            .tabItem {
                Label("Content", systemImage: "house")
            }

            VStack {
                OhSnapView(viewModel: .init(snapshot: client, serverClient: client))
            }
            .tabItem {
                Label("Snapshots", systemImage: "camera")
            }


        }
    }
}
