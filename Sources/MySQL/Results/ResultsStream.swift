import Core

protocol ResultsStream : OutputStream, ClosableStream {
    var columns: [Field] { get set }
    var header: UInt64? { get set }
    var mysql41: Bool { get }
    
    func parseRows(from packet: Packet) throws -> Output
}

fileprivate let serverMoreResultsExists: UInt16 = 0x0008

extension ResultsStream {
    public func inputStream(_ input: Packet) {
        do {
            guard let header = self.header else {
                let parser = Parser(packet: input)
                
                guard let header = try? parser.parseLenEnc() else {
                    if case .error(let error) = try input.parseResponse(mysql41: mysql41) {
                        self.errorStream?(error)
                    }
                    return
                }
                
                self.header = header
                return
            }
            
            guard columns.count == header else {
                parseColumns(from: input, amount: header)
                return
            }
            
            try preParseRows(from: input)
        } catch {
            errorStream?(error)
        }
    }
    
    func preParseRows(from packet: Packet) throws {
        // End of file packet
        if packet.payload[0] == 0xfe {
            let parser = Parser(packet: packet)
            parser.position = 1
            let flags = try parser.parseUInt16()
            
            if flags & serverMoreResultsExists == 0 {
                return
            }
            
            onClose?()
            return
        }
        
        // If it's an error packet
        if packet.payload.count > 0,
            let pointer = packet.payload.baseAddress,
            pointer[0] == 0xff,
            let error = try packet.parseResponse(mysql41: self.mysql41).error {
                throw error
        }
        
        self.outputStream?(try parseRows(from: packet))
    }
    
    func parseColumns(from packet: Packet, amount: UInt64) {
        if amount == 0 {
            self.columns = []
        }
        
        // EOF
        if packet.isResponse {
            do {
                switch try packet.parseResponse(mysql41: mysql41) {
                case .error(let error):
                    self.errorStream?(error)
                    return
                case .ok(_):
                    fallthrough
                case .eof(_):
                    guard amount == columns.count else {
                        self.errorStream?(MySQLError.invalidPacket)
                        return
                    }
                }
            } catch {
                self.errorStream?(MySQLError.invalidPacket)
                return
            }
        }
        
        let parser = Parser(packet: packet)
        
        do {
            let catalog = try parser.parseLenEncString()
            let database = try parser.parseLenEncString()
            let table = try parser.parseLenEncString()
            let originalTable = try parser.parseLenEncString()
            let name = try parser.parseLenEncString()
            let originalName = try parser.parseLenEncString()
            
            parser.position += 1
            
            let charSet = try parser.byte()
            let collation = try parser.byte()
            
            let length = try parser.parseUInt32()
            
            guard let fieldType = Field.FieldType(rawValue: try parser.byte()) else {
                throw MySQLError.invalidPacket
            }
            
            let flags = Field.Flags(rawValue: try parser.parseUInt16())
            
            let decimals = try parser.byte()
            
            let field = Field(catalog: catalog,
                              database: database,
                              table: table,
                              originalTable: originalTable,
                              name: name,
                              originalName: originalName,
                              charSet: charSet,
                              collation: collation,
                              length: length,
                              fieldType: fieldType,
                              flags: flags,
                              decimals: decimals)
            
            self.columns.append(field)
        } catch {
            self.errorStream?(MySQLError.invalidPacket)
            return
        }
    }
}
