import Async

final class RowStream : ResultsStream {
    func close() {
        self.onClose?()
    }
    
    /// Parses a packet into a Row
    func parseRows(from packet: Packet) throws -> Row {
        return try packet.makeRow(columns: columns)
    }
    
    init(mysql41: Bool) {
        self.mysql41 = mysql41
    }
    
    /// A list of all fields' descriptions in this table
    var columns = [Field]()
    
    /// The header is used to indicate the amount of returned columns
    var header: UInt64?
    
    typealias Notification = Row
    
    var outputStream: NotificationCallback?
    
    let errorNotification = SingleNotification<Error>()
    
    let mysql41: Bool
    
    var onClose: CloseHandler?
    
    typealias Input = Packet
}
