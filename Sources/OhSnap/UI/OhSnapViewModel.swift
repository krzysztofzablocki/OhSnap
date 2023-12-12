import Combine
import SwiftUI

public protocol OhSnapServerClient {
    /// Downloads all available snapshots.
    func fetchSnapshots() async throws -> [OhSnapClient.Snapshot]

    /// Uploads the snapshot directory to Firebase Storage.
    func uploadSnapshot() async throws -> OhSnapClient.Snapshot

    /// Removes specified snapshot
    func removeSnapshot(_ snapshot: OhSnapClient.Snapshot) async throws

    /// Downloads the snapshot data from Firebase Storage and unpacks it to the specified directory.
    func downloadAndUnpack(_ snapshot: OhSnapClient.Snapshot) async throws
}

@MainActor
public class SnapshotModeViewModel: ObservableObject {
    var ohSnap: OhSnapClient
    let serverClient: OhSnapServerClient

    @Published private var snapshots: [OhSnapClient.Snapshot] = []
    var snapshotList: [OhSnapClient.Snapshot] {
        snapshots.sorted { $0.date > $1.date }
    }

    @Published var isDownloading = false
    @Published var isUploading = false
    @Published var error: String?
    var errorPresented: Bool {
        get {
            error != nil
        }
        set {
            if newValue == false {
                error = nil
            }
        }
    }

    private var cancellables = Set<AnyCancellable>()
    public init(snapshot: OhSnapClient, serverClient: OhSnapServerClient) {
        self.ohSnap = snapshot
        self.serverClient = serverClient
        snapshot.objectWillChange.sink { _ in
            self.objectWillChange.send()
        }
        .store(in: &cancellables)
    }

    // Fetch list of available snapshots from Firebase
    func fetchSnapshots() async {
        isDownloading = true
        defer {
            isDownloading = false
        }

        do {
            self.snapshots = try await serverClient.fetchSnapshots()
        } catch {
            self.error = "Error fetching snapshots: \(error.localizedDescription)"
        }
    }

    // Remove a snapshot from Firebase
    func removeSnapshot(_ snapshot: OhSnapClient.Snapshot) async {
        do {
            try await serverClient.removeSnapshot(snapshot)
            snapshots.removeAll(where: { $0.id == snapshot.id })
        } catch {
            self.error = "Error removing snapshot: \(error.localizedDescription)"
        }
    }

    func uploadSnapshot() async {
        guard ohSnap.mode == .recording else {
            print("Upload is only allowed in recording mode")
            return
        }

        isUploading = true
        defer {
            isUploading = false
        }
        do {
            let snapshot = try await serverClient.uploadSnapshot()
            self.snapshots.append(snapshot)
        } catch {
            self.error = error.localizedDescription
        }
    }

    // Download and set mode to replay
    func downloadAndSetToReplay(_ snapshot: OhSnapClient.Snapshot) async {
        isDownloading = true
        defer {
            isDownloading = false
        }
        do {
            try await serverClient.downloadAndUnpack(snapshot)
            ohSnap.mode = .replaying
        } catch {
            self.error = "Error downloading snapshot: \(error.localizedDescription)"
        }
    }
}
