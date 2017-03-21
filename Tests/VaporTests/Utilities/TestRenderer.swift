import Vapor

final class TestRenderer: ViewRenderer {
    let viewsDir: String
    var views: [String: Bytes]

    init(viewsDir: String) {
        self.viewsDir = viewsDir
        self.views = [:]
    }

    enum Error: Swift.Error {
        case viewNotFound
    }

    func make(_ path: String, _ context: Node, for provider: Provider.Type?) throws -> View {
        guard let bytes = self.views[path] else {
            throw Error.viewNotFound
        }

        return View(data: bytes)
    }
}
