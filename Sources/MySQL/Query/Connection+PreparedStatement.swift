import Async
import Bits
import Foundation

extension MySQLConnection {
    /// https://mariadb.com/kb/en/library/com_stmt_prepare/
    ///
    /// Prepares a query and returns a prepared statement that can be used for binding and execution
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/databases/mysql/prepared-statements/)
    func prepare(query: Query) -> Future<PreparedStatement> {
        let promise = Promise<PreparedStatement>()
        var statement: PreparedStatement?
        
        self.receivePackets { packet in
            if let statement = statement {
                do {
                    if statement.columns.count < statement.columnCount {
                        statement.columns.append(try packet.parseFieldDefinition())
                    } else if statement.parameters.count < statement.parameterCount {
                        statement.parameters.append(try packet.parseFieldDefinition())
                    }
                    
                    if statement.columns.count == statement.columnCount && statement.parameters.count == statement.parameterCount {
                        promise.complete(statement)
                    }
                } catch {
                    promise.fail(error)
                }
            } else {
                guard packet.payload.count == 12, packet.payload.first == 0x00 else {
                    promise.fail(MySQLError(packet: packet))
                    return
                }
                
                let parser = Parser(packet: packet, position: 1)
                
                do {
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
                    }
                    
                    statement = preparedStatement
                } catch {
                    promise.fail(error)
                }
            }
        }
        
        self.parser.catch(promise.fail)
        
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
        
        do {
            let promise = Promise<Void>()
            
            self.receivePackets { packet in
                guard packet.payload.first == 0x00 else {
                    promise.fail(MySQLError(packet: packet))
                    return
                }
                
                promise.complete()
            }
            
            try self.write(packetFor: data)
            
            return promise.future
        } catch {
            return Future(error: error)
        }
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
