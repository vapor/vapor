//import JSON
//import Fluent
//import TypeSafeRouting
//import HTTP
//
//@_exported import class Fluent.Database
//
//public protocol Modelz: Entity, JSONRepresentable, StringInitializable, ResponseRepresentable { }
//
//extension Modelz {
//    public func makeResponse() throws -> Response {
//        return try makeJSON().makeResponse()
//    }
//}
//
//// MARK: JSONRepresentable
//
//extension Modelz {
//    public func makeJSON() throws -> JSON {
//        let node = try makeNode()
//        return try JSON(node: node)
//    }
//}
//
//// MARK: StringInitializable
//
//extension Modelz {
//    public init?(from string: String) throws {
//        if let model = try Self.find(string) {
//            self = model
//        } else {
//            return nil
//        }
//    }
//}
