import Configuration
import ConsoleLogger
import Foundation
import Logging
import Vapor

let isLoggingConfigured: Bool = {
    LoggingSystem.bootstrap(config: ConfigReader(provider: InMemoryProvider(values: ["log.level": "debug"])))
    return true
}()

func env(_ name: String) -> String? {
    ProcessInfo.processInfo.environment[name]
}
