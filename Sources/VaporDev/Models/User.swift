import Vapor

final class User {
    var name: String
    
    init(name: String) {
        self.name = name
    }
}

extension User: ResponseConvertible {
    func response() -> Response {
        return Json([
            "name": "\(name)"
        ]).response()
    }
}

extension User: CustomStringConvertible {
    var description: String {
        return "[User: \(name)]"
    }
}

extension User: StringInitializable {
    convenience init?(from string: String) throws {
        self.init(name: string)
    }
}