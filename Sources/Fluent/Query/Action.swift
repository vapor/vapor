/// The types of actions that can be performed
/// while querying a database, such as fetching, deleting,
/// creating, and updating.
public enum QueryAction {
    case create
    case read
    case update
    case delete
    case aggregate(Aggregate, entity: String?, field: String?)
}
