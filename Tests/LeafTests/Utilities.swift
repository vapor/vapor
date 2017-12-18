import Async
import Bits
import COperatingSystem
import Dispatch
import Foundation
import JunkDrawer
import Leaf

extension LeafRenderer {
    static func makeTestRenderer(worker: Worker) -> LeafRenderer {
        let config = LeafConfig { _ in
            return TestFiles()
        }
        return LeafRenderer(config: config, on: worker)
    }
}

final class TestFiles: FileReader, FileCache {
    func fileExists(at path: String) -> Bool {
        return false
    }

    func directoryExists(at path: String) -> Bool {
        return false
    }

    init() {}

    func getCachedFile(at path: String) -> Data? {
        return nil
    }

    func setCachedFile(file: Data?, at path: String) {
        // nothing
    }

    func read<S>(at path: String, into stream: S, chunkSize: Int) where S : Async.InputStream, S.Input == ByteBuffer {
        let data = """
        Test file name: "\(path)"
        """.data(using: .utf8)!
        data.withByteBuffer(stream.next)
        stream.close()
    }
}

final class PreloadedFiles: FileReader, FileCache {
    var files: [String: Data]
    init() {
        files = [:]
    }

    func getCachedFile(at path: String) -> Data? {
        return nil
    }

    func setCachedFile(file: Data?, at path: String) {
        // nothing
    }

    func read<S>(at path: String, into stream: S, chunkSize: Int) where S : Async.InputStream, S.Input == ByteBuffer {
        if let data = files[path] {
            data.withByteBuffer(stream.next)
        } else {
            stream.error("Could not find file")
        }
        stream.close()
    }

    func directoryExists(at path: String) -> Bool {
        return false
    }

    func fileExists(at path: String) -> Bool {
        return false
    }
}

extension String: Error {}
