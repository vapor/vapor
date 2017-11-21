import CSourceKit
import Foundation
import Bits

public final class Library {
    public static var shared = Library()

    let sourcekitd: DynamicLinkLibrary

    init() {
        sourcekitd = toolchainLoader.loadSourcekitd()
        sourcekitd_initialize()
    }

    public func parseFile(at path: String) throws -> File {
        let url = URL(fileURLWithPath: path)
        let data = try Data(contentsOf: url)
        return try File(data)
    }

    public func parseFile(_ data: Data) throws -> File {
        return try File(data)
    }
}

extension String: Error {}
