/// Filter.Relation <-> String
extension Filter.Relation {
    public var string: String {
        switch(self) {
        case .and: return "and"
        case .or: return "or"
        }
    }

    public init(_ string: String) throws {
        switch(string) {
        case Filter.Relation.and.string: self = .and
        case Filter.Relation.or.string: self = .or
        default: throw FilterSerializationError.undefinedRelation(string)
        }
    }
}
