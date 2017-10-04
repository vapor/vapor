// TIDI: Filter Decodable

//import Foundation
//
//extension Filter: NodeConvertible {
//    public init(node: Node) throws {
//        let entityName: String = try node.get("entity")
//        let entityClass: AnyClass? = NSClassFromString(entityName)
//        guard let entity = entityClass as? Entity.Type else {
//            throw FilterSerializationError.undefinedEntity(entityName)
//        }
//
//        self.entity = entity
//        self.method = try Method(node: try node.get("method"))
//    }
//
//    public func makeNode(in context: Context?) throws -> Node {
//        var node = Node([:])
//        let entityName = String(reflecting: entity).components(separatedBy: ".Type")[0]
//        try node.set("entity", entityName)
//        try node.set("method", try self.method.makeNode(in: context))
//        return node
//    }
//}
//
//enum FilterSerializationError: Error {
//    case undefinedEntity(String)
//    case undefinedComparison(String)
//    case undefinedScope(String)
//    case undefinedRelation(String)
//    case undefinedMethodType(String)
//    case other(String)
//}
//
//extension FilterSerializationError: Debuggable {
//    public var identifier: String {
//        switch self {
//        case .undefinedEntity:
//            return "undefinedEntity"
//        case .undefinedComparison:
//            return "undefinedComparison"
//        case .undefinedScope:
//            return "undefinedScope"
//        case .undefinedRelation:
//            return "undefinedRelation"
//        case .undefinedMethodType:
//            return "undefinedMethodType"
//        case .other:
//            return "other"
//        }
//    }
//
//    public var reason: String {
//        switch self {
//        case .undefinedEntity(let s):
//            return "Entity not defined: \(s)"
//        case .undefinedComparison(let s):
//            return "Comparison not defined: \(s)"
//        case .undefinedScope(let s):
//            return "Scope not defined: \(s)"
//        case .undefinedRelation(let s):
//            return "Relation not defined: \(s)"
//        case .undefinedMethodType(let s):
//            return "Method type not defined: \(s))"
//        case .other(let s):
//            return "Other: \(s)"
//        }
//    }
//
//    public var possibleCauses: [String] {
//        switch self {
//        case .undefinedEntity:
//            return [
//                "There is a mistake in the provided entity",
//                "The entity is not defined or does not inherit from Fluent.Entity"
//            ]
//        case .undefinedComparison:
//            return [
//                "There is a mistake in the provided comparison",
//                "The provided comparison is not defined"
//            ]
//        case .undefinedScope:
//            return [
//                "There is a mistake in the provided scope",
//                "The provided scope is not defined"
//            ]
//        case .undefinedRelation:
//            return [
//                "There is a mistake in the provided relation",
//                "The provided relation is not defined"
//            ]
//        case .undefinedMethodType:
//            return [
//                "There is a mistake in the provided method type",
//                "The provided method type is not defined"
//            ]
//        case .other:
//            return [
//                "Something wrong happened"
//            ]
//        }
//    }
//
//    public var suggestedFixes: [String] {
//        switch self {
//        case .undefinedEntity:
//            return [
//                "Type the entity correctly: \"ModuleName.EntityName\"",
//                "Use a defined entity that inherits from Fluent.Entity"
//            ]
//        case .undefinedComparison:
//            return [
//                "Type the comparison correctly: \"equals\", \"notEquals\", \"greaterThan\", ...",
//                "Use one of the defined comparisons: see Fluent.Filter.Comparison"
//            ]
//        case .undefinedScope:
//            return [
//                "Type the scope correctly: \"in\", \"notIn\"",
//                "Use one of the defined comparisons: \"in\", \"notIn\""
//            ]
//        case .undefinedRelation:
//            return [
//                "Type the relation correctly: \"and\", \"or\"",
//                "Use one of the defined relations: \"and\", \"or\""
//            ]
//        case .undefinedMethodType:
//            return [
//                "Type the method type correctly: \"compare\", \"subset\", \"group\"",
//                "Use one of the defined methods type: \"compare\", \"subset\", \"group\""
//            ]
//        case .other:
//            return []
//        }
//    }
//}
//
//
