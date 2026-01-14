import ConsoleLogger
import Foundation
import Logging
import Vapor

let isLoggingConfigured: Bool = {
    ConsoleLogger.bootstrap()
    return true
}()

func env(_ name: String) -> String? {
    ProcessInfo.processInfo.environment[name]
}
