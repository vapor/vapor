import Async

public final class ModelStream<D: Decodable> : ResultsStream {
    public func close() {
        self.onClose?()
    }
    
    public var onClose: CloseHandler?
    
    /// A list of all fields' descriptions in this table
    var columns = [Field]()
    
    /// The header is used to indicate the amount of returned columns
    var header: UInt64?
    
    let mysql41: Bool
    
    public typealias Output = D
    
    public var outputStream: OutputHandler?
    
    public var errorStream: ErrorHandler?
    
    init(mysql41: Bool) {
        self.mysql41 = mysql41
    }
    
    /// Parses a packet into a Decodable entity
    func parseRows(from packet: Packet) throws -> D {
        let row = try packet.makeRow(columns: columns)
        
        let decoder = try RowDecoder(keyed: row, lossyIntegers: true, lossyStrings: true)
        return try D(from: decoder)
    }
    
}

