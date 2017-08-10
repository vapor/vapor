import Node

/// Structured Data Wrapper for view specific operations
public struct ViewData: StructuredDataWrapper {
    public static let defaultContext: Context? = ViewContext.shared

    public var wrapped: StructuredData
    public var context: Context

    public init(_ wrapped: StructuredData, in context: Context?) {
        self.wrapped = wrapped
        self.context = context ?? emptyContext
    }
}

public protocol ViewDataRepresentable {
    func makeViewData() throws -> ViewData
}

public protocol ViewDataInitializable {
    init(viewData: ViewData) throws
}

public typealias ViewDataConvertible = ViewDataRepresentable & ViewDataInitializable

extension ViewData: ViewDataConvertible {
    public func makeViewData() -> ViewData {
        return self
    }

    public init(viewData: ViewData) {
        self = viewData
    }
}

extension ViewData: FuzzyConverter {
    public static func represent<T>(
        _ any: T,
        in context: Context
    ) throws -> Node? {
        guard context.isViewContext else {
            return nil
        }

        guard let r = any as? ViewDataRepresentable else {
            return nil
        }

        return try r.makeViewData().converted()
    }

    public static func initialize<T>(
        node: Node
    ) throws -> T? {
        guard node.context.isViewContext else {
            return nil
        }

        guard let type = T.self as? ViewDataInitializable.Type else {
            return nil
        }

        let viewData = node.converted(to: ViewData.self)
        return try type.init(viewData: viewData) as? T
    }
}
