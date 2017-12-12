import Async
import Foundation
import JunkDrawer

extension MySQLConnection {
    /// Writes a query to the connection
    ///
    /// Doesn't handle anything else
    internal func write(query: String) throws {
        var buffer = Data()
        buffer.reserveCapacity(query.utf8.count + 1)
        
        // SQL Query
        buffer.append(0x03)
        buffer.append(contentsOf: [UInt8](query.utf8))
        
        try self.write(packetFor: buffer)
    }
    
    /// Writes a preparation message to the connection
    internal func prepare(query: String) throws {
        var buffer = Data()
        buffer.reserveCapacity(query.utf8.count + 1)
        
        // SQL Query
        buffer.append(0x16)
        buffer.append(contentsOf: [UInt8](query.utf8))
        
        try self.write(packetFor: buffer)
    }
    
    /// An internal function that shoots a raw query without expecting a real answer
    @discardableResult
    public func administrativeQuery(_ query: MySQLQuery) -> Completable {
        let promise = Promise<Void>()
        
        self.packetStream.drain { packet in
            // Expect an `OK` or `EOF` packet
            if packet.payload.first == 0xff {
                // Otherwise, reutrn an error
                promise.fail(MySQLError(packet: packet))
                return
            }
            
            promise.complete()
        }.catch(onError: promise.fail)
        .finally(onClose:  { promise.complete() })
        
        do {
            try self.write(query: query.queryString)
        } catch {
            return Future(error: error)
        }
        
        return promise.future
    }
}
