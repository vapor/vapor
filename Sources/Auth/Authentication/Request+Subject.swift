import Turnstile
import HTTP

extension Subject {
    var sessionIdentifier: String? {
        return authDetails?.sessionID
    }
}

extension Request {
    func subject() throws -> Subject {
        guard let subject = storage["subject"] as? Subject else {
            throw AuthError.noSubject
        }

        return subject
    }
}
