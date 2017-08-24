import Core
import Dispatch
import Foundation
import Leaf
import libc

extension Renderer {
    static func makeTestRenderer() -> Renderer {
        return Renderer(tags: defaultTags, fileReader: TestFiles())
    }
}

final class TestFiles: FileReader {
    init() {}


    func read(at path: String, on queue: DispatchQueue) -> Future<Data> {
        let data = """
            Test file name: "\(path)"
            """.data(using: .utf8)!

        let promise = Promise(Data.self)
        promise.complete(data)
        return promise.future
    }
}

final class PreloadedFiles: FileReader {
    var files: [String: Data]
    init() {
        files = [:]
    }

    func read(at path: String, on queue: DispatchQueue) -> Future<Data> {
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
