import Async
import Bits
import Foundation

/// A statement that has been bound and is ready for execution
public final class BoundStatement {
    /// The statement to bind to
    let statement: PreparedStatement
    
    /// The amount of bound parameters
    var boundParameters = 0
    
    /// The internal cache used to build up the header and null map of the query
    var header = Data([
        0x17, // Header
        0,0,0,0, // statementId
        0, // flags
        1, 0, 0, 0 // iteration count (always 1)
    ])
    
    // Stores the bound parameters
    var parameterData = Data()
    
    /// Creates a new BoundStatemnt
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
    /// Executes the bound statement
    ///
    /// TODO: Support cursors
    ///
    /// Flags:
    ///     0    no cursor
    ///     1    read only
    ///     2    cursor for update
    ///     4    scrollable cursor
    func execute() throws {
        guard boundParameters == statement.parameters.count else {
            throw MySQLError(.notEnoughParametersBound)
        }
        
        try statement.connection.write(packetFor: header + parameterData)
    }
    
    /// Fetched `count` more results from MySQL
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
    
    /// Executes the bound statement and returns all decoded results in a future array
    public func all<D: Decodable>(_ type: D.Type) -> Future<[D]> {
        let promise = Promise<[D]>()
        var results = [D]()
        
        // Set up a parser
        let resultBuilder = ModelStream<D>(mysql41: statement.connection.mysql41, binary: true)
        statement.connection.packetStream.stream(to: resultBuilder)

        /// FIXME: close should propogate
        resultBuilder.finally {
            promise.complete(results)
        }

        resultBuilder.drain { result in
            results.append(result)
        }.catch { error in
            promise.fail(error)
        }.finally {
            promise.complete(results)
        }
        
        // Send the query
        do {
            try execute()
            try getMore(count: UInt32.max)
        } catch {
            return Future(error: error)
        }
        
        return promise.future
    }
    
    /// Executes the bound statement and returns all decoded results as a Stream
    public func stream<D: Decodable>(_ type: D.Type) throws -> ModelStream<D> {
        let stream = ModelStream<D>(mysql41: true, binary: true)
        
        // Set up a parser
        statement.connection.packetStream.stream(to: stream)
        
        // Send the query
        try execute()
        try getMore(count: UInt32.max)
        
        return stream
    }
}
