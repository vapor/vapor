public enum SQLQuery {
    case schema(SchemaQuery)
    case data(DataQuery)
    // TODO: transaction
    // TODO: permission
    // TODO: session
}
