import Foundation
import SwiftUI

@MainActor
struct NewsView: View {
    @Bindable var viewModel: NewsViewModel

    var body: some View {
        NavigationStack {
            List {
                if let error = viewModel.error {
                    Text(error)
                } else {
                    ForEach(viewModel.articles) { article in
                        Text(article.title)
                    }
                }
            }
        }
        .task {
            await viewModel.refresh()
        }
        .searchable(text: $viewModel.query, prompt: "Manipulate Server Data")
        .onChange(of: viewModel.query, { _, new in
            if new.isEmpty {
                Task {
                    await viewModel.refresh()
                }
            }
        })
        .onSubmit(of: .search, {
            Task {
                await viewModel.refresh()
            }
        })
    }
}
