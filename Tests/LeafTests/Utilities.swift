import Async
import Core
import Dispatch
import Foundation
import Leaf
import libc

extension LeafRenderer {
    static func makeTestRenderer(worker: Worker) -> LeafRenderer {
        let config = LeafConfig(tags: defaultTags, fileFactory: TestFiles.init)
        return LeafRenderer(config: config, worker: worker)
    }
}

final class TestFiles: FileReader, FileCache {

    // worker as a workaround for file factory
    init(_ worker: Worker? = nil) {}

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
    
    // worker as a workaround for file factory
    init(worker: Worker? = nil) {
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

import Service

final class BasicContainer: Container {
    var config: Config
    var environment: Environment
    var services: Services
    var extend: Extend

    init(services: Services) {
        self.config = Config()
        self.environment = .development
        self.services = services
        self.extend = Extend()
    }
}
