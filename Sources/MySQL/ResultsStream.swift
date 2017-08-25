import Core

protocol ResultsStream : Stream {
    associatedtype Input = Packet
    associatedtype Result
    associatedtype Output = Optional<Result>
    
    var columns: [Field] { get set }
    var header: UInt64? { get set }
    var endOfResults: Bool { get }
    var resultsProcessed: UInt64 { get set }
    var connection: Connection { get }
    
    func parseRows(from packet: Packet) throws -> Output
    func complete()
}

extension ResultsStream {
    func inputStream(_ input: Packet) {
        do {
            guard let header = self.header else {
                let parser = Parser(packet: input)
                
                guard let header = try? parser.parseLenEnc() else {
                    if case .error(let error) = try input.parseResponse(mysql41: connection.mysql41) {
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
            
            let result = try parseRows(from: input)
            self.outputStream?(result)
            resultsProcessed += 1
            
            guard resultsProcessed < header else {
                complete()
                return
            }
        } catch {
            errorStream?(error)
        }
    }
    
    func parseColumns(from packet: Packet, amount: UInt64) {
        if amount == 0 {
            self.columns = []
        }
        
        // EOF
        if packet.isResponse {
            do {
                switch try packet.parseResponse(mysql41: connection.mysql41 == true) {
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

class ResultsBuilder : ResultsStream {
    var endOfResults = false
    fileprivate let serverMoreResultsExists: UInt16 = 0x0008
    
    func parseRows(from packet: Packet) throws -> Row? {
        do {
            if packet.payload.count == 5, packet.payload[0] == 0xfe {
                let parser = Parser(packet: packet)
                let flags = try parser.parseUInt16()
                self.endOfResults = (flags & serverMoreResultsExists) == 0
                return nil
            }
        } catch {
            self.errorStream?(error)
            return nil
        }
        
        if packet.payload.count > 0,
            let pointer = packet.payload.baseAddress,
            pointer[0] == 0xff,
            let error = try packet.parseResponse(mysql41: self.connection.mysql41).error {
            self.errorStream?(error)
            return nil
        }
        
        let parser = Parser(packet: packet)
        var row = Row()
        
        for field in columns {
            if field.isBinary {
                let value = try parser.parseLenEncData()
                
                try row.append(value, forField: field)
            } else {
                let value = try parser.parseLenEncString()
                
                try row.append(value, forField: field)
            }
        }
        
        return row
    }
    
    init(connection: Connection) {
        self.connection = connection
    }
    
    func complete() {
        self.outputStream?(nil)
    }
    
    var connection: Connection
    var columns = [Field]()
    var header: UInt64?
    var resultsProcessed: UInt64 = 0
    typealias Result = Row
    typealias Output = Row?
    
    var outputStream: OutputHandler?
    
    var errorStream: ErrorHandler?
    
    typealias Input = Packet
}

class ModelBuilder<D: Table> : ResultsStream {
    var endOfResults = false
    fileprivate let serverMoreResultsExists: UInt16 = 0x0008
    
    func parseRows(from packet: Packet) throws -> D? {
        do {
            if packet.payload.count == 5, packet.payload[0] == 0xfe {
                let parser = Parser(packet: packet)
                let flags = try parser.parseUInt16()
                self.endOfResults = (flags & serverMoreResultsExists) == 0
                return nil
            }
        } catch {
            self.errorStream?(error)
            return nil
        }
        
        if packet.payload.count > 0,
            let pointer = packet.payload.baseAddress,
            pointer[0] == 0xff,
            let error = try packet.parseResponse(mysql41: self.connection.mysql41).error {
            self.errorStream?(error)
            return nil
        }
        
        let parser = Parser(packet: packet)
        var row = Row()
        
        for field in columns {
            if field.isBinary {
                let value = try parser.parseLenEncData()
                
                try row.append(value, forField: field)
            } else {
                let value = try parser.parseLenEncString()
                
                try row.append(value, forField: field)
            }
        }
        
        let decoder = try RowDecoder(keyed: row, lossyIntegers: true, lossyStrings: true)
        return try D(from: decoder)
    }
    
    init(connection: Connection) {
        self.connection = connection
    }
    
    func complete() {
        self.outputStream?(nil)
    }
    
    var connection: Connection
    var columns = [Field]()
    var header: UInt64?
    var resultsProcessed: UInt64 = 0
    typealias Result = D
    typealias Output = D?
    
    var outputStream: OutputHandler?
    
    var errorStream: ErrorHandler?
    
    typealias Input = Packet
}

