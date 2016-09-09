import HTTP
import URI

extension Request {
    convenience init(method: Method, path: String, host: String = "0.0.0.0") {
        let uri = URI(host: host, path: path)
        try! self.init(method: method, uri: uri)
    }
}
