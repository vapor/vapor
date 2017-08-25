import Foundation
import Core

extension Table {
    static func query(_ sql: String, onConnection connection: Connection) throws -> ResultStream<Self> {
        // Cannot send another SQL query before the other one is done
        _ = try connection.currentQueryFuture?.sync()

        let resultBuilder = ModelBuilder<Self>(connection: connection)

        let done = connection.onPackets(resultBuilder.inputStream)

        let resultStream = ResultStream<Self> {
            done.complete(true)
        }

        resultStream.errorStream = { error in
            done.fail(error)
        }

        resultBuilder.drain(into: resultStream)

        var buffer = Data()
        buffer.reserveCapacity(sql.utf8.count + 1)

        // SQL Query
        buffer.append(0x03)
        buffer.append(contentsOf: [UInt8](sql.utf8))

        try connection.write(packetFor: buffer)

        return resultStream
    }
}

extension Connection {
    func query(_ sql: String) throws -> ResultStream<Row> {
        // Cannot send another SQL query before the other one is done
        _ = try self.currentQueryFuture?.sync()

        let resultBuilder = ResultsBuilder(connection: self)

        let done = self.onPackets(resultBuilder.inputStream)

        let resultStream = ResultStream<Row> {
            done.complete(true)
        }

        resultStream.errorStream = { error in
            done.fail(error)
        }

        resultBuilder.drain(into: resultStream)

        var buffer = Data()
        buffer.reserveCapacity(1 + sql.utf8.count)

        // SQL Query
        buffer.append(0x03)
        buffer.append(contentsOf: [UInt8](sql.utf8))

        try self.write(packetFor: buffer)

        return resultStream
    }
}
