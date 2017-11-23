import Async
import Core
import Dispatch
import Foundation
import Leaf
import libc

extension LeafRenderer {
    static func makeTestRenderer() -> LeafRenderer {
        return LeafRenderer(tags: defaultTags) { queue in
            return TestFiles()
        }
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

import Service

final class BasicContainer: Container {
    var config: Config
    var environment: Environment
    var services: Services
    var extend: Extend
    var serviceCache: ServiceCache

    init(services: Services) {
        self.config = Config()
        self.environment = .development
        self.services = services
        self.serviceCache = .init()
        self.extend = Extend()
    }
}
