import HTTP
import Turnstile

public final class Helper {
    public let request: Request
    public init(request: Request) {
        self.request = request
    }

    public var header: Authorization? {
        guard let authorization = request.headers["Authorization"] else {
            return nil
        }

        return Authorization(header: authorization)
    }

    public func login(_ credentials: Credentials, persist: Bool = true) throws {
        return try request.subject().login(credentials: credentials, persist: persist)
    }
}

extension Request {
    public var auth: Helper {
        let key = "auth"

        guard let helper = storage[key] as? Helper else {
            let helper = Helper(request: self)
            storage[key] = helper
            return helper
        }

        return helper
    }
}

