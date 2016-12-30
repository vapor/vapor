import HTTP
import Turnstile

public final class Helper {
    public weak var request: Request?
    public init(request: Request) {
        self.request = request
    }

    public var header: Authorization? {
        guard let authorization = request?.headers["Authorization"] else {
            return nil
        }

        return Authorization(header: authorization)
    }

    public func login(_ credentials: Credentials, persist: Bool = true) throws {
        try request?.subject().login(credentials: credentials, persist: persist)
    }
    
    public func logout() throws {
        try request?.subject().logout()
    }

    public func user() throws -> User {
        let subject = try request?.subject()

        guard let details = subject?.authDetails else {
            throw AuthError.notAuthenticated
        }

        guard let user = details.account as? User else {
            throw AuthError.invalidAccountType
        }
        
        return user
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

