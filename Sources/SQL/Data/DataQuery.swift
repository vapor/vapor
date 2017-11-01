/// SQL data manipulation query (DML)
public struct DataQuery {
    public var statement: DataStatement
    public var table: String
    public var columns: [DataColumn]
    public var computed: [DataComputed]
    public var joins: [Join]
    public var predicates: [Predicate]
    public var orderBys: [OrderBy]
    public var limit: Int?
    public var offset: Int?

    public init(
        statement: DataStatement,
        table: String,
        columns: [DataColumn] = [],
        computed: [DataComputed] = [],
        joins: [Join] = [],
        predicates: [Predicate] = [],
        orderBys: [OrderBy] = [],
        limit: Int? = nil,
        offset: Int? = nil
    ) {
        self.statement = statement
        self.table = table
        self.columns = columns
        self.computed = computed
        self.joins = joins
        self.predicates = predicates
        self.orderBys = orderBys
        self.limit = limit
        self.offset = offset
    }
}

public struct OrderBy {
    public var columns: [DataColumn]
    public var direction: OrderByDirection

    public init(
        columns: [DataColumn],
        direction: OrderByDirection = .descending
    ) {
        self.columns = columns
        self.direction = direction
    }
}

public enum OrderByDirection {
    case ascending
    case descending
}

public struct DataComputed {
    public var function: String
    public var columns: [DataColumn]
    public var key: String?

    public init(
        function: String,
        columns: [DataColumn] = [],
        key: String? = nil
    ) {
        self.function = function
        self.columns = columns
        self.key = key
    }
}
