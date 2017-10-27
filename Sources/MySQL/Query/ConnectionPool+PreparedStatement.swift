import Async
import Foundation

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
    
    public func bind<T>(run closure: @escaping ((PreparationBinding) -> T)) -> T {
        let binding = PreparationBinding(forStatement: self)
        
        return closure(binding)
    }
}

public final class PreparationBinding {
    let statement: PreparedStatement
    
    var packet = Data([
        0x17, // Header
        0,0,0,0, // statementId
        0, // flags
        1, 0, 0, 0 // iteration count (always 1)
    ])
    
    var parameterData = Data()
    
    var boundParameters = 0
    
    init(forStatement statement: PreparedStatement) {
        self.statement = statement
        
        packet.withUnsafeMutableBytes { (pointer: UnsafeMutablePointer<UInt32>) in
            pointer.pointee = statement.statementID
        }
        
        for _ in 0..<(statement.parameterCount + 7)/8 {
            packet.append(0)
        }
        
        // Types are sent to the server
        packet.append(1)
    }
    
    /// https://mariadb.com/kb/en/library/com_stmt_execute/
    ///
    /// TODO: Support cursors
    func execute() throws {
        try statement.connection.write(packetFor: packet + parameterData)
    }
    
    func bind(fieldType: UInt8, unsigned: Bool) throws {
        guard boundParameters < statement.parameterCount else {
            throw MySQLError(.tooManyParametersBound)
        }
        
        packet.append(fieldType)
        packet.append(unsigned ? 128 : 0)
    }
    
    public func all<D: Decodable>(_ type: D.Type) -> Future<[D]> {
        let promise = Promise<[D]>()
        var results = [D]()
        
        // Set up a parser
        let resultBuilder = ModelStream<D>(mysql41: statement.connection.mysql41)
        statement.connection.receivePackets(into: resultBuilder.inputStream)
        
        resultBuilder.onClose = {
            promise.complete(results)
        }
        
        resultBuilder.errorStream = { error in
            promise.fail(error)
        }
        
        resultBuilder.drain { result in
            results.append(result)
        }
        
        // Send the query
        do {
            try self.execute()
        } catch {
            return Future(error: error)
        }
        
        return promise.future
    }
    
    public func stream<D: Decodable>(_ type: D.Type, in query: Query) throws -> ModelStream<D> {
        let stream = ModelStream<D>(mysql41: true)
        
        // Set up a parser
        statement.connection.receivePackets(into: stream.inputStream)
        
        // Send the query
        try self.execute()
        
        return stream
    }
}

extension ConnectionPool {
    public func withPreparation<T>(statement: Query, run closure: @escaping ((PreparedStatement) throws -> Future<T>)) -> Future<T> {
        return self.retain { connection, complete, fail in
            connection.prepare(query: statement).flatten(closure).then(callback: complete).catch(callback: fail)
        }
    }
}
