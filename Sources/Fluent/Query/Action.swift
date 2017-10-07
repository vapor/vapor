/// The types of actions that can be performed
/// on database entities, such as fetching, deleting,
/// creating, and updating.
public enum Action {
    case fetch
    case aggregate(field: String?, Aggregate)
    case delete
    case create
    case modify
    // FIXME:
    // case schema(Schema)
}
