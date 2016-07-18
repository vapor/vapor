import Fluent
import Engine

import protocol Base.Extractable

public typealias Database = Fluent.Database

public typealias DatabaseDriver = Fluent.Driver
public typealias DatabaseModel = Fluent.Model

public typealias Preparation = Fluent.Preparation
public typealias PreparationError = Fluent.PreparationError

public typealias Query = Fluent.Query
public typealias FluentValue = Fluent.Value
public typealias Schema = Fluent.Schema

extension Extractable where Wrapped == FluentValue {
    public var isNull: Bool {
        return extract()?.isNull ?? false
    }
    public var bool: Bool? {
        return extract()?.bool
    }
    public var float: Float? {
        return extract()?.float
    }
    public var double: Double? {
        return extract()?.double
    }
    public var int: Int? {
        return extract()?.int
    }
    public var string: String? {
        return extract()?.string
    }
    public var array: [Polymorphic]? {
        return extract()?.array
    }
    public var object: [String: Polymorphic]? {
        return extract()?.object
    }
}

public protocol RequestInitializable {
    init(request: HTTPRequest) throws
}
