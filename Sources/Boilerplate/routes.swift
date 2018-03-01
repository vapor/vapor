import Vapor

let http = HTTPResponse()

public func routes(_ router: Router) throws {
    router.get("ping") { req in
        return "123" as StaticString
    }
}
