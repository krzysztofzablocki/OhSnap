import XCTest
@testable import OhSnap

@MainActor
final class SnapshotModeTests: XCTestCase {
    var fileManagerClientMock: SnapshotModeFileManagerClient!
    var userDefaultsClientMock: SnapshotModeUserDefaultsClient!
    var baseURL: URL!
    var userDefaults: [String: Any]!
    var fileExistsReturnValue: Bool!
    var fileContents: [URL: Data]!

    override func setUp() {
        super.setUp()

        fileExistsReturnValue = false
        fileContents = [:]
        userDefaults = [:]

        baseURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("SnapshotModeTests")

        fileManagerClientMock = SnapshotModeFileManagerClient(
            fileExists: { [unowned self] path in
                return fileExistsReturnValue || fileContents.keys.contains(URL(fileURLWithPath: path))
            },
            createDirectory: { [unowned self] url, _, _ in
                guard !fileExistsReturnValue else {
                    throw NSError(domain: NSCocoaErrorDomain, code: NSFileWriteFileExistsError, userInfo: nil)
                }
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
                fileExistsReturnValue = true // Simulate successful directory creation
            },
            contentsOfDirectory: { [unowned self] url, _, _ in
                return Array(fileContents.keys)
            },
            removeItem: { [unowned self] url in
                fileContents[url] = nil
            },
            moveItem: { [unowned self] from, to in
                fileContents[to] = fileContents[from]
                fileContents[from] = nil
            }
        )

        userDefaultsClientMock = SnapshotModeUserDefaultsClient(
            string: { [unowned self] key in
                return userDefaults[key] as? String
            },
            set: { [unowned self] value, key in
                userDefaults[key] = value
            }
        )
    }

    override func tearDown() {
        fileManagerClientMock = nil
        userDefaultsClientMock = nil
        baseURL = nil
        userDefaults = nil
        fileExistsReturnValue = nil
        fileContents = nil

        super.tearDown()
    }
    func  test_init_creates_directory_when_none_exists() {
        // Arrange
        XCTAssertFalse(fileExistsReturnValue)

        // Act
        let _ = OhSnapClient(defaultMode: .disabled, restorePrevious: false, baseURL: baseURL, fileManager: fileManagerClientMock, userDefaults: userDefaultsClientMock)

        // Assert
        XCTAssertEqual(fileExistsReturnValue, true)
    }

    func test_init_does_not_create_directory_when_already_present() {
        // Arrange
        fileExistsReturnValue = true

        // Act & Assert (No exceptions should be thrown)
        XCTAssertNoThrow(
            _ = OhSnapClient(defaultMode: .disabled, restorePrevious: false, baseURL: baseURL, fileManager: fileManagerClientMock, userDefaults: userDefaultsClientMock)
        )
    }

    // MARK: - State Restoration Tests

    func test_restore_sets_state_from_user_defaults_when_valid() async {
        // Arrange
        userDefaults[OhSnapClient.UserDefaultsKeys.recordingModeKey.rawValue] = OhSnapClient.Mode.recording.rawValue

        // Act
        let client = OhSnapClient(defaultMode: .disabled, restorePrevious: true, baseURL: baseURL, fileManager: fileManagerClientMock, userDefaults: userDefaultsClientMock)

        // Assert
        XCTAssertEqual(client.mode, .recording)
    }

    func test_restore_falls_back_to_default_when_user_defaults_state_invalid() async {
        // Arrange
        userDefaults[OhSnapClient.UserDefaultsKeys.recordingModeKey.rawValue] = "invalidState"

        // Act
        let client = OhSnapClient(defaultMode: .recording, restorePrevious: true, baseURL: baseURL, fileManager: fileManagerClientMock, userDefaults: userDefaultsClientMock)

        // Assert
        XCTAssertEqual(client.mode, .recording)
    }

    // MARK: - Registration and Module Info Tests

    func test_register_adds_files_and_module_info_returns_correct_data() {
        // Arrange
        let sut = OhSnapClient(defaultMode: .recording, restorePrevious: false, baseURL: baseURL, fileManager: fileManagerClientMock, userDefaults: userDefaultsClientMock)
        let moduleName = "TestModule"
        let files: Set<String> = ["file1", "file2"]
        sut.register(module: moduleName, files: files)
        files.forEach { filename in
            let url = baseURL.appendingPathComponent(filename)
            fileContents[url] = Data()
        }

        // Act
        sut.refreshFileList()
        let module = sut.modules[moduleName]

        // Assert
        XCTAssertEqual(module?.fileList, files)
    }

    // MARK: - Data Processing Tests

    func test_process_saves_data_to_file_in_recording_state() async throws {
        // Arrange
        let sut = OhSnapClient(defaultMode: .recording, restorePrevious: false, baseURL: baseURL, fileManager: fileManagerClientMock, userDefaults: userDefaultsClientMock)
        var testData = Data("testData".utf8)
        let identifier = "testFile"

        // Act
        testData = await sut.snapshot(testData, uniqueIdentifier: identifier)

        // Assert
        let url = baseURL.appendingPathComponent(identifier)
        XCTAssertEqual(try Data(contentsOf: url), testData)
    }

    func test_process_reads_data_from_file_in_replaying_state() async throws {
        // Arrange
        let sut = OhSnapClient(defaultMode: .replaying, restorePrevious: false, baseURL: baseURL, fileManager: fileManagerClientMock, userDefaults: userDefaultsClientMock)
        let testData = Data("testData".utf8)
        let identifier = "testFile"
        let url = baseURL.appendingPathComponent(identifier)
        try testData.write(to: url)
        fileContents[url] = testData

        // Act
        let data = await sut.snapshot(Data(), uniqueIdentifier: identifier)

        // Assert
        XCTAssertEqual(data, testData)
    }

    func test_process_returns_input_data_without_change_in_disabled_state() async {
        // Arrange
        let sut = OhSnapClient(defaultMode: .disabled, restorePrevious: false, baseURL: baseURL, fileManager: fileManagerClientMock, userDefaults: userDefaultsClientMock)
        let testData = Data("testData".utf8)
        let identifier = "testFile"

        // Act
        let data = await sut.snapshot(testData, uniqueIdentifier: identifier)

        // Assert
        XCTAssertEqual(data, testData)
        XCTAssertNil(fileContents[baseURL.appendingPathComponent(identifier)])
    }

    // MARK: - State Persistence Tests

    func test_set_state_persists_new_state_to_user_defaults() {
        // Arrange
        let sut = OhSnapClient(defaultMode: .recording, restorePrevious: false, baseURL: baseURL, fileManager: fileManagerClientMock, userDefaults: userDefaultsClientMock)

        // Act
        sut.mode = .replaying

        // Assert
        let persistedState = userDefaults[OhSnapClient.UserDefaultsKeys.recordingModeKey.rawValue] as? String
        XCTAssertEqual(persistedState, OhSnapClient.Mode.replaying.rawValue)
    }

    func test_set_state_updates_state_correctly() {
        // Arrange
        let sut = OhSnapClient(defaultMode: .disabled, restorePrevious: false, baseURL: baseURL, fileManager: fileManagerClientMock, userDefaults: userDefaultsClientMock)

        // Act
        sut.mode = .recording

        // Assert
        XCTAssertEqual(sut.mode, .recording)
    }
}
