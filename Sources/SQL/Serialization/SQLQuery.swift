public enum SQLQuery {
    case schema(SchemaQuery)
    case data(DataQuery)
    case transaction(TransactionQuery)
    // TODO: permission
    // TODO: session
}
