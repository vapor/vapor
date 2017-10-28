final class RowStream : ResultsStream {
    func close() {
        self.onClose?()
    }
    
    /// Parses a packet into a Row
    func parseRows(from packet: Packet) throws -> Row {
        return try packet.makeRow(columns: columns, binary: binary)
    }
    
    init(mysql41: Bool, binary: Bool = false) {
        self.mysql41 = mysql41
        self.binary = binary
    }
    
    /// A list of all fields' descriptions in this table
    var columns = [Field]()
    
    /// The header is used to indicate the amount of returned columns
    var header: UInt64?
    
    typealias Output = Row
    
    var outputStream: OutputHandler?
    
    var errorStream: ErrorHandler?
    
    let mysql41: Bool
    let binary: Bool
    
    var onClose: CloseHandler?
    
    typealias Input = Packet
}
