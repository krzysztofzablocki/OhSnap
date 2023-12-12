import Foundation
import AppleArchive
import System

struct UnableToPackToAAR: Error {
    var error: Error?
}

struct UnableToUnpackFromAAR: Error {
    var error: Error?
}

public extension URL {
    func packToAAR() throws -> URL {
        let archiveDestination = NSTemporaryDirectory() + "directory.aar"
        let archiveFilePath = FilePath(archiveDestination)

        guard let writeFileStream = ArchiveByteStream.fileStream(
                path: archiveFilePath,
                mode: .writeOnly,
                options: [ .create ],
                permissions: FilePermissions(rawValue: 0o644)) else {
            throw UnableToPackToAAR()
        }
        defer {
            try? writeFileStream.close()
        }

        guard let compressStream = ArchiveByteStream.compressionStream(
                using: .lzfse,
                writingTo: writeFileStream) else {
            throw UnableToPackToAAR()
        }
        defer {
            try? compressStream.close()
        }

        guard let encodeStream = ArchiveStream.encodeStream(writingTo: compressStream) else {
            throw UnableToPackToAAR()
        }
        defer {
            try? encodeStream.close()
        }

        guard let keySet = ArchiveHeader.FieldKeySet("TYP,PAT,LNK,DEV,DAT,UID,GID,MOD,FLG,MTM,BTM,CTM") else {
            throw UnableToPackToAAR()
        }

        let source = FilePath(self.path)

        do {
            try encodeStream.writeDirectoryContents(
                archiveFrom: source,
                keySet: keySet)
        } catch {
            throw UnableToPackToAAR(error: error)
        }

        return URL(fileURLWithPath: archiveFilePath.description)
    }

    func unpackAAR(to destination: URL) throws {
        let archiveFilePath = FilePath(self.path)

        guard let readFileStream = ArchiveByteStream.fileStream(
                path: archiveFilePath,
                mode: .readOnly,
                options: [ ],
                permissions: FilePermissions(rawValue: 0o644)) else {
            throw UnableToUnpackFromAAR()
        }
        defer {
            try? readFileStream.close()
        }

        guard let decompressStream = ArchiveByteStream.decompressionStream(readingFrom: readFileStream) else {
            throw UnableToUnpackFromAAR()
        }
        defer {
            try? decompressStream.close()
        }

        guard let decodeStream = ArchiveStream.decodeStream(readingFrom: decompressStream) else {
            print("unable to create decode stream")
            throw UnableToUnpackFromAAR()
        }
        defer {
            try? decodeStream.close()
        }

        let decompressPath = NSTemporaryDirectory() + "dest/"

        if !FileManager.default.fileExists(atPath: decompressPath) {
            do {
                try FileManager.default.createDirectory(atPath: decompressPath,
                                                        withIntermediateDirectories: false)
            } catch {
                throw UnableToUnpackFromAAR(error: error)
            }
        }

        let decompressDestination = FilePath(destination.path)
        guard let extractStream = ArchiveStream.extractStream(extractingTo: decompressDestination,
                                                              flags: [ .ignoreOperationNotPermitted ]) else {
            throw UnableToUnpackFromAAR()
        }
        defer {
            try? extractStream.close()
        }

        do {
            _ = try ArchiveStream.process(readingFrom: decodeStream,
                                          writingTo: extractStream)
        } catch {
            throw UnableToUnpackFromAAR(error: error)
        }
    }
}
