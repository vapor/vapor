/// SQL data manipulation query (DML)
public struct DataQuery {
    public var statement: DataStatement
    public var table: String
    public var columns: [DataColumn]
    public var computed: [DataComputed]
    public var predicates: [Predicate]
    public var joins: [Join]

    public init(
        statement: DataStatement,
        table: String,
        columns: [DataColumn] = [],
        computed: [DataComputed] = [],
        predicates: [Predicate] = [],
        joins: [Join] = []
    ) {
        self.statement = statement
        self.table = table
        self.columns = columns
        self.computed = computed
        self.predicates = predicates
        self.joins = joins
    }
}

public struct DataComputed {
    public let function: String
    public let columns: [DataColumn]
    public let key: String?

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
