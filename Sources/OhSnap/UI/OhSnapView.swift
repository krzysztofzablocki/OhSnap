import SwiftUI

public struct OhSnapView: View {
    @ObservedObject var viewModel: SnapshotModeViewModel

    public init(viewModel: SnapshotModeViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Snapshot Mode:")
                Picker("Mode", selection: $viewModel.ohSnap.mode) {
                    Text("Disabled").tag(OhSnapClient.Mode.disabled)
                    Text("Recording").tag(OhSnapClient.Mode.recording)
                    Text("Replaying").tag(OhSnapClient.Mode.replaying)
                }
                .pickerStyle(MenuPickerStyle())

                Spacer()
                Button("Upload") {
                    // Provide the URL to the directory containing snapshots to be uploaded
                    Task { await viewModel.uploadSnapshot() }
                }
                .disabled(viewModel.isUploading)
                .foregroundColor(.green)
                .opacity(viewModel.ohSnap.mode == .recording ? 1 : 0)
            }
            .padding()

            List {
                currentSnapshot

                Section("Snapshots") {
                    ForEach(viewModel.snapshotList) { snapshot in
                        HStack {
                            VStack(alignment: .leading) {
                                HStack {

                                    Text(snapshot.date, style: .date)
                                    Text(snapshot.date, style: .time)
                                }

                                Text(snapshot.name.dropLast(4))
                                    .font(.caption2)
                            }

                            Spacer()
                            Button(action: {
                                Task {
                                    await viewModel.downloadAndSetToReplay(snapshot)
                                }
                            }, label: {
                                Image(systemName: "arrow.down.circle")
                            })
                            .buttonStyle(BorderlessButtonStyle())
                            .disabled(viewModel.isDownloading)

                            Button(action: {
                                Task {
                                    await viewModel.removeSnapshot(snapshot)
                                }
                            }, label: {
                                Image(systemName: "trash")
                            })
                            .buttonStyle(BorderlessButtonStyle())
                        }
                    }
                }
            }
        }
        .overlay {
            // Downloading/Uploading Indicator
            if viewModel.isDownloading {
                ProgressView("Downloading…")
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.gray)
                    )
            } else if viewModel.isUploading {
                ProgressView("Uploading…")
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.gray)
                    )
            }
        }
        .task {
            await viewModel.fetchSnapshots()
        }
        .alert("Error", isPresented: $viewModel.errorPresented) {
            Button("Ok", role: .cancel) { }
        } message: {
            Text(viewModel.error ?? "")
        }
        .animation(.easeInOut, value: viewModel.ohSnap.mode)
        .animation(.bouncy, value: viewModel.snapshotList)
    }

    @ViewBuilder
    private var currentSnapshot: some View {
        Section("Modules") {
            ForEach(Array(viewModel.ohSnap.modules.values)) { module in
                let complete = module.fileList.count == module.required.count
                HStack {
                    Text(module.name)
                    Spacer()
                    Image(systemName: complete ? "checkmark.circle" : "xmark.circle")
                }

                ForEach(Array(module.fileList), id: \.self) { file in
                    Label(file, systemImage: "checkmark.circle")
                }

                ForEach(Array(module.required.subtracting(module.fileList)), id: \.self) { file in
                    Label(file, systemImage: "xmark.circle")
                }
            }
        }
    }
}
