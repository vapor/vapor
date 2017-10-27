import Async
import Bits
import Foundation

extension Connection {
    /// https://mariadb.com/kb/en/library/com_stmt_prepare/
    func prepare(query: Query) -> Future<PreparedStatement> {
        let promise = Promise<PreparedStatement>()
        
        self.receivePackets { packet in
            guard packet.payload.count == 12, packet.payload.first == 0x00 else {
                promise.fail(MySQLError(.invalidPacket))
                return
            }
            
            let parser = Parser(packet: packet, position: 1)
            
            do {
                let statementID = try parser.parseUInt32()
                let columnCount = try parser.parseUInt16()
                let parameterCount = try parser.parseUInt16()
                
                promise.complete(
                    PreparedStatement(
                        statementID: statementID,
                        columnCount: columnCount,
                        connection: self,
                        parameterCount: parameterCount
                    )
                )
            } catch {
                promise.fail(error)
            }
        }
        
        do {
            try self.prepare(query: query.string)
            return promise.future
        } catch {
            return Future(error: error)
        }
    }
    
    /// https://mariadb.com/kb/en/com_stmt_reset/
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
                
                promise.complete(())
            }
            
            try self.write(packetFor: data)
            
            return promise.future
        } catch {
            return Future(error: error)
        }
    }
    
    /// https://mariadb.com/kb/en/library/3-binary-protocol-prepared-statements-com_stmt_close/
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
