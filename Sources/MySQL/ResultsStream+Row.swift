class ResultsBuilder : ResultsStream {
    /// Parses a packet into a Row
    func parseRows(from packet: Packet) throws -> Row {
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
    
    /// Streams `nil` for end of stream
    var complete: (()->())?
    
    /// The connection that the results are streamed frmo
    var connection: Connection
    
    /// A list of all fields' descriptions in this table
    var columns = [Field]()
    
    /// The header is used to indicate the amount of returned columns
    var header: UInt64?
    
    typealias Output = Row
    
    var outputStream: OutputHandler?
    
    var errorStream: ErrorHandler?
    
    typealias Input = Packet
}
