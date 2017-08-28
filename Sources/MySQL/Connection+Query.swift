import Foundation
import Core

extension Decodable {
    static func forEach(_ sql: String, onConnection connection: Connection, _ handler: @escaping ((Self) -> ())) throws {
        // Cannot send another SQL query before the other one is done
        _ = try connection.currentQueryFuture?.sync()

        let resultBuilder = ModelBuilder<Self>(connection: connection)

        let done = connection.onPackets(resultBuilder.inputStream)
        
        resultBuilder.complete = {
            done.complete(true)
        }
        
        resultBuilder.errorStream = { error in
            done.fail(error)
        }

        resultBuilder.drain(handler)

        var buffer = Data()
        buffer.reserveCapacity(sql.utf8.count + 1)

        // SQL Query
        buffer.append(0x03)
        buffer.append(contentsOf: [UInt8](sql.utf8))

        try connection.write(packetFor: buffer)

        return
    }
}

extension Connection {
    func query(_ sql: String, _ handler: @escaping ((Row) -> ())) throws {
        // Cannot send another SQL query before the other one is done
        _ = try self.currentQueryFuture?.sync()

        let resultBuilder = ResultsBuilder(connection: self)

        let done = self.onPackets(resultBuilder.inputStream)

        resultBuilder.complete = {
            done.complete(true)
        }

        resultBuilder.errorStream = { error in
            done.fail(error)
        }

        resultBuilder.drain(handler)

        var buffer = Data()
        buffer.reserveCapacity(1 + sql.utf8.count)

        // SQL Query
        buffer.append(0x03)
        buffer.append(contentsOf: [UInt8](sql.utf8))

        try self.write(packetFor: buffer)
    }
}
