import Async

public struct PreparedStatement {
    let statementID: UInt32
    let columnCount: UInt16
    let connection: Connection
    let parameterCount: UInt16
    
    public func close() {
        connection.closeStatement(self)
    }
    
    public func reset() -> Future<Void> {
        return connection.resetPreparedStatement(self)
    }
    
    public func withPreparationBinding<T>(run closure: @escaping ((PreparationBinding) -> ())) -> Future<T> {
        let binding = PreparationBinding(forStatement: self)
        
        closure(self.binding)
        
        return
    }
}

public final class PreparationBinding {
    let statement: PreparedStatement
    
    init(forStatement statement: PreparationBinding) {
        self.statement = statement
    }
    
    
}

extension ConnectionPool {
    public func withPreparation<T>(statement: Query, run closure: @escaping ((PreparedStatement) throws -> Future<T>)) -> Future<T> {
        return self.retain { connection, complete, fail in
            connection.prepare(query: statement).flatten(closure).then(callback: complete).catch(callback: fail)
        }
    }
}
