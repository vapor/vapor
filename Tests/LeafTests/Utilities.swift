import Async
import Core
import Dispatch
import Foundation
import Leaf
import libc

extension LeafRenderer {
    static func makeTestRenderer(eventLoop: EventLoop) -> LeafRenderer {
        let config = LeafConfig { _ in
            return TestFiles()
        }
        return LeafRenderer(config: config, on: eventLoop)
    }
}

final class TestFiles: FileReader, FileCache {
    func fileExists(at path: String) -> Bool {
        return false
    }


    init() {}

    func getCachedFile(at path: String) -> Data? {
        return nil
    }

    func setCachedFile(file: Data?, at path: String) {
        // nothing
    }

    func read<S>(at path: String, into stream: S, chunkSize: Int) where S : Async.InputStream, S.Input == Data {
        let data = """
        Test file name: "\(path)"
        """.data(using: .utf8)!
        stream.onInput(data)
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

    func read<S>(at path: String, into stream: S, chunkSize: Int) where S : Async.InputStream, S.Input == Data {
        if let data = files[path] {
            stream.onInput(data)
        } else {
            stream.onError("Could not find file")
        }
        stream.close()
    }

    func fileExists(at path: String) -> Bool {
        return false
    }
}
