import HTTP
import URI

extension Request {
    convenience init() {
        self.init(method: .get, uri: URI(host: "test", path: "/"))
    }
}

extension Response {
    convenience init() {
        self.init(status: .ok)
    }
}
