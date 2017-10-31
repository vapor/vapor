public enum SchemaStatement {
    case create(columns: [SchemaColumn])
    case alter(columns: [SchemaColumn], deleteColumns: [String])
    case drop
}
