/// The types of actions that can be performed
/// on database entities, such as fetching, deleting,
/// creating, and updating.
public enum QueryAction {
    case create
    case read
    case update
    case delete
    case aggregate(Aggregate, field: String?)

}
