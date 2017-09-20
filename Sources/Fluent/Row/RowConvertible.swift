// MARK: Convertible

public protocol RowConvertible: RowRepresentable, RowInitializable {}

// MARK: Representable

public protocol RowRepresentable {
    func makeRow() throws -> Row
}

// MARK: Initializable

public protocol RowInitializable {
    init(row: Row) throws
}
