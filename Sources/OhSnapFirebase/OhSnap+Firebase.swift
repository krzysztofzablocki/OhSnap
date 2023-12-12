import Foundation
import OhSnap
import FirebaseStorage

extension OhSnapClient: OhSnapServerClient {
    static private var prefix: String { "ohSnap-snapshots" }

    /// Downloads all available snapshots.
    public func fetchSnapshots() async throws -> [Snapshot] {
        let storageRef = Storage.storage().reference(withPath: Self.prefix)

        let result = try await storageRef.listAll()
        var snapshots = [OhSnapClient.Snapshot]()
        for item in result.items {
            let metadata = try await item.getMetadata()
            if let snapshot = Snapshot(metadata: metadata.customMetadata ?? [:]) {
                snapshots.append(snapshot)
            }
        }

        return snapshots
    }

    /// Uploads the snapshot directory to Firebase Storage.
    public func uploadSnapshot() async throws -> Snapshot {
        // Pack the snapshots directory
        let aarURL = try baseURL.packToAAR()

        // Create a reference to the Firebase Storage path
        let snapshotName = "\(UUID().uuidString).aar"
        let storagePath = "\(Self.prefix)/\(snapshotName)"
        let storageRef = Storage.storage().reference(withPath: storagePath)
        let metadata = StorageMetadata()
        metadata.contentType = "application/aar"

        let date = Date()
        let list = Array(fileList)
        let newSnapshot = Snapshot(name: snapshotName, date: date, fileList: list)
        metadata.customMetadata = newSnapshot.metadata

        defer {
            try? FileManager.default.removeItem(at: aarURL)
        }

        _ = try await storageRef.putFileAsync(from: aarURL, metadata: metadata)
        return newSnapshot
    }

    /// Removes specified snapshot
    public func removeSnapshot(_ snapshot: Snapshot) async throws {
        try await Storage.storage().reference().child("\(Self.prefix)/\(snapshot.name)").delete()
    }

    /// Downloads the snapshot data from Firebase Storage and unpacks it to the specified directory.
    public func downloadAndUnpack(_ snapshot: Snapshot) async throws {
        let storageRef = Storage.storage().reference().child("\(Self.prefix)/\(snapshot.name)")
        let localAarURL = URL(fileURLWithPath: NSTemporaryDirectory() + "\(UUID().uuidString).aar")
        let unpackDirectory = URL(fileURLWithPath: NSTemporaryDirectory() + "\(UUID().uuidString)-unpack/")
        try fileManager.createDirectory(unpackDirectory, true, nil)

        // Download the packed file
        _ = try await storageRef.writeAsync(toFile: localAarURL)
        try localAarURL.unpackAAR(to: unpackDirectory)
        try fileManager.removeItem(self.baseURL)
        try fileManager.moveItem(unpackDirectory, self.baseURL)

        // Clean up the local archive file
        try? fileManager.removeItem(localAarURL)
    }
}
