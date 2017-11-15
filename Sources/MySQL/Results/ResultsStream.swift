import Async
import libc

/// A type that can parse streaming query results
protocol ResultsStream : OutputStream, ClosableStream {
    /// Keeps track of all columns associated with the results
    var columns: [Field] { get set }
    
    /// Used to indicate the amount of returned columns
    var columnCount: UInt64? { get set }
    
    /// Keeps track of the server's protocol version for reading
    var mysql41: Bool { get }
    
    func parseRows(from packet: Packet) throws -> Output
}

/// The "moreResultsExists" flag
///
/// TODO: Use this with cursor support
fileprivate let serverMoreResultsExists: UInt16 = 0x0008

extension ResultsStream {
    /// Parses an incoming packet as part of the results
    func inputStream(_ input: Packet) {
        do {
            // If the header (column count) is not yet set
            guard let columnCount = self.columnCount else {
                // Parse the column count
                let parser = Parser(packet: input)
                
                // Tries to parse the header count
                guard let columnCount = try? parser.parseLenEnc() else {
                    if case .error(let error) = try input.parseResponse(mysql41: mysql41) {
                        self.errorStream?(error)
                    } else {
                        self.close()
                    }
                    return
                }
                
                // No columns means an empty stream
                if columnCount == 0 {
                    self.close()
                }
                
                self.columnCount = columnCount
                return
            }
            
            // if the column count isn't met yet
            if columns.count != columnCount {
                // Parse the next column
                parseColumns(from: input)
                return
            }
            
            // Otherwise, parse the next row
            try preParseRows(from: input)
        } catch {
            errorStream?(error)
        }
    }
    
    /// Parses a row from this packet, checks
    func preParseRows(from packet: Packet) throws {
        // End of file packet
        if packet.payload[0] == 0xfe {
            let parser = Parser(packet: packet)
            parser.position = 1
            let flags = try parser.parseUInt16()
            
            if flags & serverMoreResultsExists != 0 {
                return
            }
            
            close()
            return
        }
        
        // If it's an error packet
        if packet.payload.count > 0,
            let pointer = packet.payload.baseAddress,
            pointer[0] == 0xff,
            let error = try packet.parseResponse(mysql41: self.mysql41).error {
            print(error)
                throw error
        }
        
        self.output(try parseRows(from: packet))
    }
    
    /// Parses the packet as a columm specification
    func parseColumns(from packet: Packet) {
        // Normal responses indicate an end of columns or an error
        if packet.isTextProtocolResponse {
            do {
                switch try packet.parseResponse(mysql41: mysql41) {
                case .error(let error):
                    // Errors are thrown into the stream
                    self.errorStream?(error)
                    return
                case .ok(_):
                    fallthrough
                case .eof(_):
                    // If this is the end of the stream, stop
                    return
                }
            } catch {
                self.errorStream?(MySQLError(.invalidPacket))
                return
            }
        }
        
        do {
            // Parse the column field definition
            let field = try packet.parseFieldDefinition()
            
            self.columns.append(field)
        } catch {
            self.errorStream?(MySQLError(.invalidPacket))
            return
        }
    }
}
