class ResultsBuilder : ResultsStream {
    /// Parses a packet into a Row
    func parseRows(from packet: Packet) throws -> Row {
        return try packet.makeRow(columns: columns)
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
