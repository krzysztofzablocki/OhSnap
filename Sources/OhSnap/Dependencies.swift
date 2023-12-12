import Foundation

/// Struct-based dependency for abstracting file operations.
public struct SnapshotModeFileManagerClient {
    public var fileExists: (String) -> Bool
    public var createDirectory: (URL, Bool, [FileAttributeKey: Any]?) throws -> Void
    public var contentsOfDirectory: (URL, [URLResourceKey]?, FileManager.DirectoryEnumerationOptions) throws -> [URL]
    public var removeItem: (URL) throws -> Void
    public var moveItem: (URL, URL) throws -> Void
}

/// Struct-based dependency for abstracting user defaults operations.
public struct SnapshotModeUserDefaultsClient {
    public var string: (String) -> String?
    public var set: (Any?, String) -> Void
}

public extension SnapshotModeFileManagerClient {
    static var live: Self {
        .init(
            fileExists: FileManager.default.fileExists(atPath:),
            createDirectory: { try FileManager.default.createDirectory(at: $0, withIntermediateDirectories: $1, attributes: $2) },
            contentsOfDirectory: { try FileManager.default.contentsOfDirectory(at: $0, includingPropertiesForKeys: $1, options: $2) },
            removeItem: { try FileManager.default.removeItem(at: $0) },
            moveItem: { try FileManager.default.moveItem(at: $0, to: $1) }
        )
    }
}

public extension SnapshotModeUserDefaultsClient {
    static var live: Self {
        .init(
            string: UserDefaults.standard.string(forKey:),
            set: { UserDefaults.standard.set($0, forKey: $1) }
        )
    }
}
