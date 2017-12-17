import Async

/// A stream of decoded rows related to a query
///
/// This API is currently internal so we don't break the public API when finalizing the "raw" row API
final class RowStream: ProtocolParserStream {
    /// See InputStream.Input
    typealias Input = Packet
    
    /// See OutputStream.Output
    typealias Output = Row
    
    var backlog: [Row]
    
    var consumedBacklog: Int
    
    var downstreamDemand: UInt
    
    var upstream: ConnectionContext?
    
    var downstream: AnyInputStream<Row>?
    
    var state: ProtocolParserState
    
    typealias PacketOKSetter = ((UInt64, UInt64) -> ())

    /// A list of all fields' descriptions in this table
    var columns = [Field]()

    /// Used to indicate the amount of returned columns
    var columnCount: UInt64?

    /// If `true`, the server protocol version is for MySQL 4.1
    let mysql41: Bool
    
    /// Used to reserve capacity when parsing rows
    var reserveCapacity: Int? = nil

    /// If `true`, the results are using the binary protocols
    var binary: Bool
    
    var packetOKcallback: PacketOKSetter?

    /// Handles EOF
    typealias OnEOF = (UInt16) throws -> ()

    /// Called on EOF packet
    var onEOF: OnEOF?
    
    /// Creates a new RowStream using the specified protocol (from MySQL 4.0 or 4.1) and optionally the binary protocol instead of text
    init(mysql41: Bool, binary: Bool = false, packetOKcallback: PacketOKSetter? = nil) {
        self.mysql41 = mysql41
        self.binary = binary
        self.packetOKcallback = packetOKcallback
        
        self.backlog = []
        self.consumedBacklog = 0
        self.downstreamDemand = 0
        self.state = .ready
        
        self.onEOF = { _ in self.close() }
    }

    func transform(_ input: Packet) throws {
        // If the header (column count) is not yet set
        guard let columnCount = self.columnCount else {
            // Parse the column count
            var parser = Parser(packet: input)
            
            // Tries to parse the header count
            guard let columnCount = try? parser.parseLenEnc() else {
                if case .error(let error) = try input.parseResponse(mysql41: mysql41) {
                    throw error
                } else {
                    self.close()
                }
                return
            }

            // No columns means that this is likely the success response of a binary INSERT/UPDATE/DELETE query
            if columnCount == 0 {
                guard binary else {
                    throw MySQLError(packet: input)
                }
                
                if let (affectedRows, lastInsertID) = try input.parseBinaryOK() {
                    self.packetOKcallback?(affectedRows, lastInsertID)
                }
                
                self.close()
                return
            }
            
            self.columnCount = columnCount
            return
        }

        // if the column count isn't met yet
        if columns.count != columnCount {
            // Parse the next column
            try parseColumns(from: input)
            return
        }

        // Otherwise, parse the next row
        try preParseRows(from: input)
    }

    /// Parses a row from this packet, checks
    func preParseRows(from packet: Packet) throws {
        // End of file packet
        if packet.payload.first == 0xfe {
            var parser = Parser(packet: packet)
            parser.position = 1
            let flags = try parser.parseUInt16()

            if flags & serverMoreResultsExists == 0 {
                self.close()
                return
            }

            try onEOF?(flags)
            return
        }

        // If it's an error packet
        if packet.payload.count > 0,
            let pointer = packet.payload.baseAddress,
            pointer[0] == 0xff,
            let error = try packet.parseResponse(mysql41: self.mysql41).error
        {
            throw error
        }
        
        let row = try packet.parseRow(columns: columns, binary: binary, reserveCapacity: reserveCapacity)
        
        if reserveCapacity == nil {
            self.reserveCapacity = row.fields.count
        }
        
        flush(row)
    }

    /// Parses the packet as a columm specification
    func parseColumns(from packet: Packet) throws {
        // Normal responses indicate an end of columns or an error
        if packet.isTextProtocolResponse {
            do {
                switch try packet.parseResponse(mysql41: mysql41) {
                case .error(let error):
                    throw error
                case .ok(_):
                    fallthrough
                case .eof(_):
                    // If this is the end of the stream, stop
                    return
                }
            } catch {
                throw MySQLError(.invalidPacket)
            }
        }
        
        do {
            // Parse the column field definition
            let field = try packet.parseFieldDefinition()

            self.columns.append(field)
        } catch {
            throw MySQLError(.invalidPacket)
        }
    }
}

fileprivate let serverMoreResultsExists: UInt16 = 0x0008
