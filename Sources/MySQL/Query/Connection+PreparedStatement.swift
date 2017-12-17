import Async
import Bits
import Foundation

extension MySQLConnection {
    /// https://mariadb.com/kb/en/library/com_stmt_prepare/
    ///
    /// Prepares a query and returns a prepared statement that can be used for binding and execution
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/databases/mysql/prepared-statements/)
    func prepare(query: MySQLQuery) -> Future<PreparedStatement> {
        let promise = Promise<PreparedStatement>()
        var statement: PreparedStatement?
        
        _ = self.parser.drain { parser in
            parser.request()
        }.output { packet in
            if packet.payload.first == 0xfe {
                self.parser.request()
                // Ignore `0xfe` payloads, since we skip past those in the above `do {} catch {}`
                return
            }
            
            if let statement = statement {
                // Continue processing the statement preparation
                if statement.columns.count < statement.columnCount {
                    statement.columns.append(try packet.parseFieldDefinition())
                } else if statement.parameters.count < statement.parameterCount {
                    statement.parameters.append(try packet.parseFieldDefinition())
                }
                
                if statement.columns.count == statement.columnCount && statement.parameters.count == statement.parameterCount {
                    promise.complete(statement)
                } else {
                    self.parser.request()
                }
            } else {
                // Statement preparation details not yet read
                guard packet.payload.count == 12, packet.payload.first == 0x00 else {
                    throw MySQLError(packet: packet)
                }
                
                var parser = Parser(packet: packet, position: 1)
                
                let statementID = try parser.parseUInt32()
                let columnCount = try parser.parseUInt16()
                let parameterCount = try parser.parseUInt16()
                
                let preparedStatement = PreparedStatement(
                    statementID: statementID,
                    columnCount: columnCount,
                    connection: self,
                    parameterCount: parameterCount
                )
                
                if columnCount == 0 && parameterCount == 0 {
                    promise.complete(preparedStatement)
                    return
                }
                
                statement = preparedStatement
                self.parser.request()
            }
        }.catch(onError: promise.fail)
        
        do {
            try self.prepare(query: query.queryString)
            return promise.future
        } catch {
            return Future(error: error)
        }
    }
    
    /// https://mariadb.com/kb/en/com_stmt_reset/
    ///
    /// Resets a prepared statement so it can be re-used for another binding + execution
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/databases/mysql/prepared-statements/)
    func resetPreparedStatement(_ statement: PreparedStatement) -> Future<Void> {
        var data = Data(repeating: 0x1a, count: 5)
        
        data.withUnsafeMutableBytes { (pointer: MutableBytesPointer) in
            pointer.advanced(by: 1).withMemoryRebound(to: UInt32.self, capacity: 1) { pointer in
                pointer.pointee = statement.statementID
            }
        }
        
        let promise = Promise<Void>()
        
        _ = self.parser.drain { connection in
            connection.request()
        }.output { packet in
            guard packet.payload.first == 0x00 else {
                promise.fail(MySQLError(packet: packet))
                return
            }
            
            promise.complete()
        }.catch(onError: promise.fail)
        
        self.serializer.queue(Packet(data: data))
        
        return promise.future
    }
    
    /// https://mariadb.com/kb/en/library/3-binary-protocol-prepared-statements-com_stmt_close/
    ///
    /// Closes (cleans up) the statement
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/databases/mysql/prepared-statements/)
    func closeStatement(_ statement: PreparedStatement) {
        var data = Data(repeating: 0x19, count: 5)
        
        data.withUnsafeMutableBytes { (pointer: MutableBytesPointer) in
            pointer.advanced(by: 1).withMemoryRebound(to: UInt32.self, capacity: 1) { pointer in
                pointer.pointee = statement.statementID
            }
        }
        
        _ = try? self.write(packetFor: data)
    }
}
