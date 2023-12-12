import Foundation

/// OhSnap allows one to register data points for snapshot recording / replay
/// This class is actor-isolated to ensure thread-safety and uses async/await for concurrency.
@MainActor
public class OhSnapClient: ObservableObject {
    enum Level: String, RawRepresentable {
        case info
        case error
    }

    public struct Module: Identifiable {
        public var name: String
        public var fileList: Set<String>
        public let required: Set<String>

        public var id: String { name }
    }

    public struct Snapshot: Identifiable, Equatable {
        static let dateFormatter = ISO8601DateFormatter()

        public var id: String { name }
        public var name: String
        public var date: Date
        public var fileList: [String]

        public init(name: String, date: Date, fileList: [String]) {
            self.name = name
            self.date = date
            self.fileList = fileList
        }

        public init?(metadata: [String: String]) {
            guard
                let name = metadata["name"],
                let dateString = metadata["date"], let date = Self.dateFormatter.date(from: dateString),
                let fileList = metadata["fileList"]?.components(separatedBy: ",") else {
                return nil
            }
            self.name = name
            self.date = date
            self.fileList = fileList
        }

        public var metadata: [String: String] {
            [
                "name": name,
                "date": Self.dateFormatter.string(from: date),
                "fileList": fileList.joined(separator: ","),
            ]
        }
    }

    public var fileList: Set<String> {
        Set(((try? fileManager.contentsOfDirectory(baseURL, nil, [])) ?? []).map(\.lastPathComponent))
    }

    func log(_ level: Level, _ message: String) {
        print("\(level.rawValue): \(message)")
    }

    public enum Mode: String {
        case disabled
        case recording
        case replaying
    }

    /// The current mode of the snapshot logic.
    @Published
    public var mode: Mode {
        didSet {
            persist()
        }
    }

    /// The base URL used for storing and retrieving snapshots.
    public let baseURL: URL

    @Published public private(set) var modules = [String: Module]()
    public let fileManager: SnapshotModeFileManagerClient
    internal let userDefaults: SnapshotModeUserDefaultsClient

    /// The UserDefaults key for storing the recording mode state.
    internal enum UserDefaultsKeys: String {
        case recordingModeKey
    }

    /// Initializes a new instance of `SnapshotMode`.
    ///
    /// - Parameters:
    ///   - defaultMode: The initial state of the snapshot mode.
    ///   - restorePrevious: Whether to restore previous mode.
    ///   - baseURL: The base URL where snapshots are stored.
    ///   - fileManager: A `SnapshotModeFileManagerClient` struct for handling file operations.
    ///   - userDefaults: A `SnapshotModeUserDefaultsClient` struct for handling user defaults.
    public init(defaultMode: Mode, restorePrevious: Bool, baseURL: URL, fileManager: SnapshotModeFileManagerClient, userDefaults: SnapshotModeUserDefaultsClient) {
        let lastMode: () -> Mode = {
            guard
                let modeString = userDefaults.string(UserDefaultsKeys.recordingModeKey.rawValue),
                let mode = Mode(rawValue: modeString)
            else {
                return defaultMode
            }

            return mode
        }

        self.mode = restorePrevious ? lastMode() : defaultMode
        self.baseURL = baseURL
        self.fileManager = fileManager
        self.userDefaults = userDefaults

        if !self.fileManager.fileExists(baseURL.path) {
            do {
                try self.fileManager.createDirectory(baseURL, true, nil)
            } catch {
                log(.error, "Unable to create snapshot directory \(baseURL), error: \(error). Disabling Snapshots.")
                self.mode = .disabled
            }
        }

        refreshFileList()
    }

    /// Registers a set of files for a particular module.
    ///
    /// - Parameters:
    ///   - module: The name of the module.
    ///   - files: A set of file identifiers that belong to the module.
    public func register(module: String, files: Set<String>) {
        modules[module] = .init(name: module, fileList: [], required: .init(files))
    }

    /// Refreshes file list in modules
    public func refreshFileList() {
        var fileList = fileList
        modules[.unknownModule] = nil
        for var module in modules.values {
            module.fileList.removeAll()
            for file in module.required where fileList.contains(file) {
                module.fileList.insert(file)
                fileList.remove(file)
            }
            modules[module.name] = module
        }
        if !fileList.isEmpty {
            modules[.unknownModule] = .init(name: .unknownModule, fileList: fileList, required: fileList)
        }
    }

    /// Processes the provided data based on the current state, either by recording or replaying snapshots.
    ///
    /// - Parameters:
    ///   - data: The data to process.
    ///   - uniqueIdentifier: A unique identifier for the data, used for recording or replaying.
    /// - Returns: The processed data.
    public func snapshot(_ data: Data, uniqueIdentifier: String) async -> Data {
        defer {
            if mode == .recording {
                refreshFileList()
            }
        }

        switch mode {
        case .recording:
            let fileURL = baseURL.appendingPathComponent(uniqueIdentifier)
            do {
                try data.write(to: fileURL)
                log(.info, "Recorded snapshot to \(fileURL)")
            } catch {
                log(.error, "Unable to record \(uniqueIdentifier), error: \(error)")
            }
        case .replaying:
            let fileURL = baseURL.appendingPathComponent(uniqueIdentifier)
            do {
                return try Data(contentsOf: fileURL)
            } catch {
                log(.error, "Unable to replay \(uniqueIdentifier), error: \(error)")
            }
        case .disabled:
            log(.info, "Snapshot mode is disabled.")
        }
        return data
    }

    /// Persists the current state to user defaults.
    private func persist() {
        userDefaults.set(mode.rawValue, UserDefaultsKeys.recordingModeKey.rawValue)
    }
}

private extension String {
    static var unknownModule = "Unknown"
}
