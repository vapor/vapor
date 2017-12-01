import Async
import Core
import Dispatch
import Foundation
import Leaf
import libc

extension LeafRenderer {
    static func makeTestRenderer(on eventloop: EventLoop) -> LeafRenderer {
        let config = LeafConfig(fileReaderFactory: { _ -> TestFiles in
            return TestFiles()
        })
        
        return LeafRenderer(config: config, on: eventloop)
    }
}

final class TestFiles: FileReader, FileCache {

    init() {}

    func getFile<H: Hashable>(hash: H) -> Future<Data?> {
        return Future(nil)
    }

    func setFile<H: Hashable>(file: Data?, hash: H) {
        // nothing
    }

    func read(at path: String) -> Future<Data> {
        let data = """
            Test file name: "\(path)"
            """.data(using: .utf8)!

        let promise = Promise(Data.self)
        promise.complete(data)
        return promise.future
    }
}

final class PreloadedFiles: FileReader, FileCache {
    var files: [String: Data]
    init() {
        files = [:]
    }

    func getFile<H: Hashable>(hash: H) -> Future<Data?> {
        return Future(nil)
    }

    func setFile<H: Hashable>(file: Data?, hash: H) {
        // nothing
    }

    func read(at path: String) -> Future<Data> {
        let promise = Promise(Data.self)

        if let data = files[path] {
            promise.complete(data)
        } else {
            promise.fail("Could not find file")
        }

        return promise.future
    }
}
