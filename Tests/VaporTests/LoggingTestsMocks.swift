import Foundation
import Vapor

final class TestLogger: Logger {
    
    var logs = [String]()
        
    public func log(_ string: String, at level: LogLevel, file: String, function: String, line: UInt, column: UInt) {
        
        logs += [string]
    }
    
    func didLog(string: String) -> Bool {
        return logs.contains(string)
    }
}

extension TestLogger: Service {}

final class TestLoggerProvider: Provider {

    let logger = TestLogger()
    
    func register(_ services: inout Services) throws {
        services.register(Logger.self) { container -> TestLogger in
            return self.logger
        }
    }

    func didBoot(_ container: Container) throws -> EventLoopFuture<Void> {
        return .done(on: container)
    }
}
