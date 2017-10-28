import Async
import Bits
import Foundation

public final class PreparedStatement {
    let statementID: UInt32
    let columnCount: UInt16
    let connection: Connection
    let parameterCount: UInt16
    var columns = [Field]()
    var parameters = [Field]()
    
    public func close() {
        connection.closeStatement(self)
    }
    
    public func reset() -> Future<Void> {
        return connection.resetPreparedStatement(self)
    }
    
    public func bind(run closure: @escaping ((PreparationBinding) throws -> ())) rethrows -> BoundStatement {
        let binding = PreparationBinding(forStatement: self)
        
        try closure(binding)
        
        return BoundStatement(binding: binding)
    }
    
    init(statementID: UInt32, columnCount: UInt16, connection: Connection, parameterCount: UInt16) {
        self.statementID = statementID
        self.columnCount = columnCount
        self.connection = connection
        self.parameterCount = parameterCount
    }
    
    deinit {
        var data = Data(repeating: 0x19, count: 5)
        
        data.withUnsafeMutableBytes { (pointer: MutableBytesPointer) in
            pointer.advanced(by: 1).withMemoryRebound(to: UInt32.self, capacity: 1) { pointer in
                pointer.pointee = self.statementID
            }
        }
        
        _ = try? connection.write(packetFor: data)
    }
}

public struct BoundStatement {
    let binding: PreparationBinding
    
    init(binding: PreparationBinding) {
        self.binding = binding
    }
    
    public func all<D: Decodable>(_ type: D.Type) -> Future<[D]> {
        let promise = Promise<[D]>()
        var results = [D]()
        
        // Set up a parser
        let resultBuilder = ModelStream<D>(mysql41: binding.statement.connection.mysql41, binary: true)
        
        binding.statement.connection.receivePackets(into: resultBuilder.inputStream)
        
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
            try binding.execute()
            try binding.getMore(count: UInt32.max)
        } catch {
            return Future(error: error)
        }
        
        return promise.future
    }
    
    public func stream<D: Decodable>(_ type: D.Type, in query: Query) throws -> ModelStream<D> {
        let stream = ModelStream<D>(mysql41: true, binary: true)
        
        // Set up a parser
        binding.statement.connection.receivePackets(into: stream.inputStream)
        
        // Send the query
        try binding.execute()
        try binding.getMore(count: UInt32.max)
        
        return stream
    }
}

public final class PreparationBinding {
    let statement: PreparedStatement
    
    var header = Data([
        0x17, // Header
        0,0,0,0, // statementId
        0, // flags
        1, 0, 0, 0 // iteration count (always 1)
    ])
    
    var parameterData = Data()
    
    var boundParameters = 0
    
    init(forStatement statement: PreparedStatement) {
        self.statement = statement
        
        header.withUnsafeMutableBytes { (pointer: MutableBytesPointer) in
            pointer.advanced(by: 1).withMemoryRebound(to: UInt32.self, capacity: 1) { pointer in
                pointer.pointee = statement.statementID
            }
        }
        
        for _ in 0..<(statement.parameterCount + 7)/8 {
            header.append(0)
        }
        
        // Types are sent to the server
        header.append(1)
    }
    
    /// https://mariadb.com/kb/en/library/com_stmt_execute/
    ///
    /// TODO: Support cursors
    ///
    /// Flags:
    ///     0    no cursor
    ///     1    read only
    ///     2    cursor for update
    ///     4    scrollable cursor
    func execute() throws {
        try statement.connection.write(packetFor: header + parameterData)
    }
    
    func getMore(count: UInt32) throws {
        var data = Data(repeating: 0x1c, count: 9)
        
        data.withUnsafeMutableBytes { (pointer: MutableBytesPointer) in
            pointer.advanced(by: 1).withMemoryRebound(to: UInt32.self, capacity: 2) { pointer in
                pointer[0] = self.statement.statementID
                pointer[1] = count
            }
        }
        
        try statement.connection.write(packetFor: data)
    }
    
    func bindNil() throws {
        guard boundParameters < statement.parameterCount else {
            throw MySQLError(.tooManyParametersBound)
        }
        
        let bitmapStart = 10
        let byte = boundParameters / 8
        let bit = boundParameters % 8
        
        let bitEncoded: UInt8 = 0b00000001 << (7 - numericCast(bit))
        
        header[bitmapStart + byte] |= bitEncoded
        
        boundParameters += 1
    }
    
    func bind(fieldType: UInt8, unsigned: Bool, data: Data) throws {
        guard boundParameters < statement.parameterCount else {
            throw MySQLError(.tooManyParametersBound)
        }
        
        header.append(fieldType)
        header.append(unsigned ? 128 : 0)
        
        parameterData.append(contentsOf: data)
        
        boundParameters += 1
    }
}

extension ConnectionPool {
    public func withPreparation<T>(statement: Query, run closure: @escaping ((PreparedStatement) throws -> Future<T>)) -> Future<T> {
        return self.retain { connection, complete, fail in
            connection.prepare(query: statement).then { statement in
                do {
                    try closure(statement).then(callback: complete).catch(callback: fail)
                } catch {
                    fail(error)
                }
            }.catch(callback: fail)
        }
    }
}
