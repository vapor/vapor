/// The types of actions that can be performed
/// on database entities, such as fetching, deleting,
/// creating, and updating.
public enum Action {
    case data(DataAction)
    case schema(SchemaAction)
    case aggregate(Aggregate, field: String?)

}

public enum SchemaAction {
    case create
    case update
    case delete
}

public enum DataAction {
    case create
    case read
    case update
    case delete
}
