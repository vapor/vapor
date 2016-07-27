import enum Engine.HTTPBody
import class Engine.HTTPMessage

extension HTTPMessage {
    public var json: JSON? {
        get {
            if let existing = storage["json"] as? JSON {
                return existing
            } else if let type = headers["Content-Type"], type.contains("application/json") {
                guard case let .data(body) = body else { return nil }
                guard let json = try? JSON(bytes: body) else { return nil }
                storage["json"] = json
                return json
            } else {
                return nil
            }
        }
        set(data) {
            if let data = data {
                if let body = try? HTTPBody(data) {
                    self.body = body
                    headers["Content-Type"] = "application/json; charset=utf-8"
                }
            }
        }
    }
}
