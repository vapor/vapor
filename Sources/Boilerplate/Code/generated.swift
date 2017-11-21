/// MARK: Model

extension User: Model {
    /// See Model.keyFieldMap
    static var keyFieldMap: KeyFieldMap {
        return [
            key(\\.id): field("id"),
            key(\\.name): field("name"),
            key(\\.age): field("age"),
            key(\\.pets): field("pets"),
        ]
    \}
\}
