import Vapor

final class TestRenderer: ViewRenderer {
    var shouldCache: Bool

    let viewsDir: String
    var views: [String: Bytes]

    init(viewsDir: String) {
        self.viewsDir = viewsDir
        self.views = [:]
        self.shouldCache = false
    }

    enum Error: Swift.Error {
        case viewNotFound
    }

    func make(_ path: String, _ context: Node) throws -> View {
        guard let bytes = self.views[path] else {
            throw Error.viewNotFound
        }

        return View(data: bytes)
    }
}
