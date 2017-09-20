/// Represents a database row or entity. 
/// Fluent parses Rows from fetch queries and serializes
/// Rows to create and update queries.
public struct Row: StructuredDataWrapper {
    public static let defaultContext: Context? = rowContext
    public var wrapped: StructuredData
    public let context: Context

    public init(_ wrapped: StructuredData, in context: Context?) {
        self.wrapped = wrapped
        self.context = context ?? rowContext
    }

    public init() {
        self.init([:])
    }
}

extension Row: FuzzyConverter {
    public static func represent<T>(
        _ any: T,
        in context: Context
    ) throws -> Node? {
        guard context.isRow else {
            return nil
        }
        
        guard let r = any as? RowRepresentable else {
            return nil
        }
        
        return try r.makeRow().converted()
    }
    
    public static func initialize<T>(
        node: Node
    ) throws -> T? {
        guard node.context.isRow else {
            return nil
        }
        
        guard let type = T.self as? RowInitializable.Type else {
            return nil
        }
        
        let row = node.converted(to: Row.self)
        return try type.init(row: row) as? T
    }
}
