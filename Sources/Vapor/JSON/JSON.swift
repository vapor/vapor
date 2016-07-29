import Foundation

@_exported import JSON

extension JSON {
    public init() {
        self = .null
    }
    
    public init(_ obj: [String: JSONRepresentable]) throws {
        var json: [String: JSON] = [:]
        for (key, val) in obj {
            json[key] = try val.makeJSON()
        }
        self = .object(json)
    }

    public init(_ arr: [JSONRepresentable]) throws {
        let json = try arr.map { try $0.makeJSON() }
        self = .array(json)
    }
}
