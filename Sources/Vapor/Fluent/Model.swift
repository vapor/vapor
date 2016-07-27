import JSON
import Fluent

public protocol Model: Entity, JSONRepresentable, StringInitializable { }

extension Model {
    public init?(from string: String) throws {
        if let model = try Self.find(string) {
            self = model
        } else {
            return nil
        }
    }

    public func makeJSON() throws -> JSON {
        fatalError("Swap for real json")
//        guard let object = try makeNode().nodeObject else { return [:] }
//
//        var json: [String: JSON] = [:]
//        for (key, value) in object {
//            let jsonValue: JSON
//
////            if let value = value {
//                switch value.structuredData {
//                case .int(let int):
//                    jsonValue = .number(JSON.Number.integer(int))
//                case .string(let string):
//                    jsonValue = .string(string)
//                default:
//                    jsonValue = .null
//                }
//            } else {
//                jsonValue = .null
//            }
//
//            json[key] = jsonValue
//        }
//
//        return JSON(json)
    }
}
