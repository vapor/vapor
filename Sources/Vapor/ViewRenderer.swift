public protocol ViewRenderer {

}

import Core
import Foundation
import Leaf

public struct LeafConfig {
    let tags: [String: Tag]
    let fileReader: Leaf.FileReader

    public init(tags: [String: Tag], fileReader: Leaf.FileReader) {
        self.tags = tags
        self.fileReader = fileReader
    }
}

public struct View {
    public let data: Data

    public init(data: Data) {
        self.data = data
    }
}

public final class LeafRenderer: ViewRenderer {
    private let renderer: Renderer
    public init(config: LeafConfig) {
        renderer = Renderer(tags: config.tags, fileReader: config.fileReader)
    }

    public func make(_ path: String, context: Encodable) throws -> Future<View> {
        // FIXME: Leaf Context encoder
        return renderer.render(path: path, context: .null).map { data in
            return View(data: data)
        }
    }
}
