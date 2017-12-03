import Logging
import Vapor
import HTTP
import Foundation

public final class ToolboxLogger: Logger {
    private var messages = [LogMessage]()
    private var lock = NSLock()
    
    init(provider: ToolboxProvider) {
        provider.registerLogger(self)
    }
    
    public func drainMessages() -> [LogMessage] {
        lock.lock()
        lock.unlock()
        
        let messages = self.messages
        
        self.messages = []
        
        return messages
    }
    
    public func log(_ string: String, at level: LogLevel, file: String, function: String, line: UInt, column: UInt) {
        lock.lock()
        defer { lock.unlock() }
        
        let message = LogMessage(
            message: string,
            level: level,
            file: file,
            function: function,
            line: line,
            column: column,
            timestamp: Date()
        )
        
        messages.append(message)
    }
}

public struct LogMessage: Codable {
    var message: String
    var level: LogLevel
    var file: String
    var function: String
    var line: UInt
    var column: UInt
    
    var timestamp: Date
}
