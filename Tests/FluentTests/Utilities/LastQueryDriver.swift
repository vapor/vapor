import Fluent

class LastQueryDriver: Driver {
    var keyNamingConvention: KeyNamingConvention = .snake_case
    var idType: IdentifierType = .int
    let idKey: String = "#id"
    var queryLogger: QueryLogger?

    var lastQuery: (String, [Node])?
    var lastRaw: (String, [Node])?
    
    public func makeConnection(_ type: ConnectionType) throws -> Connection {
        return LastQueryConnection(driver: self)
    }
}

class LastQueryConnection: Connection {
    public var isClosed: Bool = false
    
    var driver: LastQueryDriver
    var queryLogger: QueryLogger?
    
    init(driver: LastQueryDriver) {
        self.driver = driver
    }
    
    @discardableResult
    func query<E>(_ query: RawOr<Query<E>>) throws -> Node {
        switch query {
        case .raw(let raw, let values):
            driver.lastRaw = (raw, values)
            return .null
        case .some(let query):
            let serializer = GeneralSQLSerializer(query)
            driver.lastQuery = serializer.serialize()
            return Node(.array([
                .object([
                    E.idKey: .number(.int(5))
                ])
            ]), in: nil)
        }
    }
}
