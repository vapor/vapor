import Async
import Bits
import Foundation

/// A single prepared statement that can be binded, executed, reset and closed
public final class PreparedStatement {
    /// The internal statement ID
    let statementID: UInt32
    
    /// The connection this statment is bound to
    let connection: Connection
    
    /// The amount of columns to be returned
    let columnCount: UInt16
    
    /// The amount of parameters that can and must be bound
    let parameterCount: UInt16
    
    /// The parsed column definition
    var columns = [Field]()
    
    /// The required parameters to be bound
    var parameters = [Field]()
    
    /// Closes/cleans up this statement
    public func close() {
        connection.closeStatement(self)
    }
    
    /// Resets this prepared statement to it's prepared state (rather than fetching/executed)
    public func reset() -> Future<Void> {
        return connection.resetPreparedStatement(self)
    }
    
    /// Executes the `closure` with the preparation binding statement
    ///
    /// The closure will be able to bind statements that ends up being bound and returned
    public func bind(run closure: @escaping ((PreparationBinding) throws -> ())) rethrows -> BoundStatement {
        let binding = PreparationBinding(forStatement: self)
        
        try closure(binding)
        
        return binding.boundStatement
    }
    
    /// Creates a new prepared statement from parsed data
    init(statementID: UInt32, columnCount: UInt16, connection: Connection, parameterCount: UInt16) {
        self.statementID = statementID
        self.columnCount = columnCount
        self.connection = connection
        self.parameterCount = parameterCount
    }
    
    deinit {
        self.close()
    }
}

public final class PreparationBinding {
    let boundStatement: BoundStatement
    
    init(forStatement statement: PreparedStatement) {
        self.boundStatement = BoundStatement(forStatement: statement)
    }
    
    /// Binds `NULL` to the next parameter
    public func bindNull() throws {
        guard boundStatement.boundParameters < boundStatement.statement.parameterCount else {
            throw MySQLError(.tooManyParametersBound)
        }
        
        let bitmapStart = 10
        let byte = boundStatement.boundParameters / 8
        let bit = boundStatement.boundParameters % 8
        
        let bitEncoded: UInt8 = 0b00000001 << (7 - numericCast(bit))
        
        boundStatement.header[bitmapStart + byte] |= bitEncoded
        
        boundStatement.boundParameters += 1
    }
    
    func bind(_ pseudoType: PseudoType, unsigned: Bool, data: Data) throws {
        guard boundStatement.boundParameters < boundStatement.statement.parameterCount else {
            throw MySQLError(.tooManyParametersBound)
        }
        
        let associatedFieldType = boundStatement.statement.parameters[boundStatement.boundParameters].fieldType
        
        // TODO: Lossy binding (UInt8 -> Int16)?
        guard pseudoType.supports(associatedFieldType) else {
            throw MySQLError(
                .invalidTypeBound(
                    got: pseudoType,
                    expected: boundStatement.statement.parameters[boundStatement.boundParameters].fieldType
                )
            )
        }
        
        boundStatement.header.append(associatedFieldType.rawValue)
        boundStatement.header.append(unsigned ? 128 : 0)
        
        boundStatement.parameterData.append(contentsOf: data)
        
        boundStatement.boundParameters += 1
    }
}

extension Connection {
    public func withPreparation<T>(statement: Query, run closure: @escaping ((PreparedStatement) throws -> Future<T>)) -> Future<T> {
        return self.prepare(query: statement).flatMap(closure)
    }
}
