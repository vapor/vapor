import Fluent

func serialize<E>(_ query: Query<E>) -> (String, [Node]) {
    let serializer = GeneralSQLSerializer(query)
    return serializer.serialize()
}
