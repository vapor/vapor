import ConsoleLogger
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import Logging
import Vapor

let isLoggingConfigured: Bool = {
    ConsoleLogger.bootstrapWithConfigReader(config: testConfigReader)
    return true
}()

func env(_ name: String) -> String? {
    ProcessInfo.processInfo.environment[name]
}
