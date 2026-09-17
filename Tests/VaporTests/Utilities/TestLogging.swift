import ConsoleLogger
import Logging
import Vapor

#if canImport(FoundationEssentials)
    import FoundationEssentials
#else
    import Foundation
#endif

let isLoggingConfigured: Bool = {
    ConsoleLogger.bootstrapWithConfigReader(config: testConfigReader)
    return true
}()

func env(_ name: String) -> String? {
    ProcessInfo.processInfo.environment[name]
}
