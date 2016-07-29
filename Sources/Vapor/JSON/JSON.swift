import Foundation

@_exported import JSON

extension JSON {
    public init() {
        self = .null
    }
    
    public init(_ obj: [String: JSONRepresentable]) {
        var json: [String: JSON] = [:]
        for (key, val) in obj {
            json[key] = val.makeJSON()
        }
        self = .object(json)
    }

    public init(_ arr: [JSONRepresentable]) {
        let json = arr.map { $0.makeJSON() }
        self = .array(json)
    }
}
