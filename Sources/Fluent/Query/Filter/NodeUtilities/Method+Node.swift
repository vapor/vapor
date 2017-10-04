// TODO: re-add filter serialization
//extension Filter.Method: NodeConvertible {
//    var string: String {
//        switch self {
//        case .compare(_, _, _): return "compare"
//        case .subset(_, _, _): return "subset"
//        case .group(_, _): return "group"
//        }
//    }
//
//    public init(node: Node) throws {
//        let type: String = try node.get("type")
//
//        if(type == "compare") {
//            let field: String = try node.get("field")
//            let comparison = try Filter.Comparison(try node.get("comparison"))
//            let value: Node = try node.get("value")
//
//            self = .compare(field, comparison, value); return
//        }
//
//        if(type == "subset") {
//            let field: String = try node.get("field")
//            let scope = try Filter.Scope(try node.get("scope"))
//            let values: [Node] = try node.get("values")
//            print(values)
//            self = .subset(field, scope, values); return
//        }
//
//        if(type == "group") {
//            let relation = try Filter.Relation(try node.get("relation"))
//            let filters = try (try node.get("filters") as [Node]).map {
//                RawOr<Filter>.some(try Filter(node: $0))
//            }
//
//            self = .group(relation, filters); return
//        }
//
//        throw FilterSerializationError.undefinedMethodType(type)
//    }
//
//    public func makeNode(in context: Context?) throws -> Node {
//        var node = Node([:])
//        try node.set("type", self.string)
//
//        if case .compare(let field, let comparison, let value) = self {
//            try node.set("field", field)
//            try node.set("comparison", comparison.string)
//            try node.set("value", value)
//        }
//
//        if case .subset(let field, let scope, let values) = self {
//            try node.set("field", field)
//            try node.set("scope", scope.string)
//            try node.set("values", values)
//        }
//
//        if case .group(let relation, let filters) = self {
//            try node.set("relation", relation.string)
//            try node.set("filters", filters.map { $0.wrapped })
//        }
//
//        return node
//    }
//}

