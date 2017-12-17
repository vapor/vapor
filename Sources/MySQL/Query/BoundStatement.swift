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
    func send() throws {
        guard boundParameters == statement.parameters.count else {
            throw MySQLError(.notEnoughParametersBound)
        }
        
        statement.connection.serializer.queue(Packet(data: header + parameterData))
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
        
        statement.connection.serializer.queue(Packet(data: data))
    }
    
    /// Executes the bound statement and returns all decoded results in a future array
    public func all<D: Decodable>(_ type: D.Type) -> Future<[D]> {
        var results = [D]()
        return self.forEach(D.self) { res in
            results.append(res)
        }.transform(to: results)
    }
    
    public func execute() throws -> Future<Void> {
        let promise = Promise<Void>()
        
        // Set up a parser
        _ = statement.connection.parser.drain { parser in
            parser.request()
        }.output { packet in
            do {
                if let (affectedRows, lastInsertID) = try packet.parseBinaryOK() {
                    self.statement.connection.affectedRows = affectedRows
                    self.statement.connection.lastInsertID = lastInsertID
                }
                
                promise.complete()
            } catch {
                promise.fail(error)
            }
        }.catch { err in
            promise.fail(err)
        }

        // Send the query
        try send()
        
        return promise.future
    }

    /// A simple callback closure
    public typealias Callback<T> = (T) throws -> ()

    /// Loops over all rows resulting from the query
    ///
    /// - parameter query: Fetches results using this query
    /// - parameter handler: Executes the handler for each `Row`
    /// - throws: Network error
    /// - returns: A future that will be completed when all results have been processed by the handler
    @discardableResult
    internal func forEachRow(_ handler: @escaping Callback<Row>) -> Future<Void> {
        let promise = Promise(Void.self)

        let rowStream = RowStream(mysql41: true, binary: true) { affectedRows, lastInsertID in
            self.statement.connection.affectedRows = affectedRows
            self.statement.connection.lastInsertID = lastInsertID
        }
        
        statement.connection.parser
            .stream(to: rowStream)
            .drain { parser in
                parser.request()
            }.output { input in
                try handler(input)
                self.statement.connection.parser.request()
            }.catch(onError: promise.fail)
            .finally { promise.complete() }

        do {
            try send()
        } catch {
            promise.fail(error)
        }

        rowStream.onEOF = { flags in
            try self.getMore(count: UInt32.max)
        }

        return promise.future
    }

    /// Loops over all rows resulting from the query
    ///
    /// - parameter type: Deserializes all rows to the provided `Decodable` `D`
    /// - parameter query: Fetches results using this query
    /// - parameter handler: Executes the handler for each deserialized result of type `D`
    /// - throws: Network error
    /// - returns: A future that will be completed when all results have been processed by the handler
    @discardableResult
    public func forEach<D>(_ type: D.Type, _ handler: @escaping Callback<D>) -> Future<Void>
        where D: Decodable
    {
        return forEachRow { row in
            let decoder = try RowDecoder(keyed: row, lossyIntegers: true, lossyStrings: true)
            try handler(D(from: decoder))
        }
    }
}

extension Packet {
    func parseBinaryOK() throws -> (UInt64, UInt64)? {
        var parser = Parser(packet: self)
        let byte = try parser.byte()
        
        if byte == 0x00 {
            return (try parser.parseLenEnc(), try parser.parseLenEnc())
        } else if byte == 0xfe {
            return nil
        } else if byte == 0xff {
            throw MySQLError(packet: self)
        }
        
        return nil
    }
}
