/// The types of actions that can be performed
/// on database entities, such as fetching, deleting,
/// creating, and updating.
public enum Action {
    case fetch([RawOr<ComputedField>])
    case aggregate(field: String?, Aggregate)
    case delete
    case create
    case modify
    case schema(Schema)
}

public enum Aggregate {
    case count
    case sum
    case average
    case min
    case max
    case custom(string: String)
}

public enum Schema {
    case create(
        fields: [RawOr<Field>],
        foreignKeys: [RawOr<ForeignKey>]
    )
    case modify(
        fields: [RawOr<Field>],
        foreignKeys: [RawOr<ForeignKey>],
        deleteFields: [RawOr<Field>],
        deleteForeignKeys: [RawOr<ForeignKey>]
    )
    case createIndex(RawOr<Index>)
    case deleteIndex(RawOr<Index>)
    case delete
}

extension Action: Equatable {
    public static func ==(lhs: Action, rhs: Action) -> Bool {
        switch (lhs, rhs) {
        case (.delete, .delete),
             (.create, .create),
             (.modify, .modify):
            return true
        case (.fetch(let a), .fetch(let b)):
             return a == b
        case (.aggregate(let a1, let a2), .aggregate(let b1, let b2)):
            return a1 == b1 && a2 == b2
            
        case (.schema(let a), .schema(let b)):
            return a == b
        default:
            return false
        }
    }
}

extension Aggregate: Equatable {
    public static func ==(lhs: Aggregate, rhs: Aggregate) -> Bool {
        switch (lhs, rhs) {
        case (.count, .count),
             (.sum, .sum),
             (.average, .average),
             (.min, .min),
             (.max, .max):
            return true
            
        case (.custom(let a), .custom(let b)):
            return a == b
            
        default:
            return false
        }
    }
}

extension Schema: Equatable {
    public static func ==(lhs: Schema, rhs: Schema) -> Bool {
        switch (lhs, rhs) {
        case (.create(let af, let afk), .create(let bf, let bfk)):
            return af == bf && afk == bfk
        case (.modify(let aa, let ab, let ac, let ad), .modify(let ba, let bb, let bc, let bd)):
            return aa == ba && ab == bb && ac == bc && ad == bd
        case (.delete, .delete):
            return true
        case (.createIndex(let a), .createIndex(let b)):
            return a == b
        case (.deleteIndex(let a), .deleteIndex(let b)):
            return a == b
        default:
            return false
        }
    }
}
