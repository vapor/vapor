public enum SchemaStatement {
    case create
    case alter
    case drop
    case rename(String)
}
