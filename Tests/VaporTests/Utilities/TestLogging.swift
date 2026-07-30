import ConsoleLogger
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import Logging
import Vapor

let isLoggingConfigured: Bool = {
    ConsoleLogger.bootstrap(config: testConfigReader)
    return true
}()

func env(_ name: String) -> String? {
    ProcessInfo.processInfo.environment[name]
}
