import Configuration
import Foundation
import Logging
import Vapor

let isLoggingConfigured: Bool = {
    try! LoggingSystem.bootstrap(from: ConfigReader(provider: InMemoryProvider(values: ["log.level": "debug"])))
    return true
}()

func env(_ name: String) -> String? {
    ProcessInfo.processInfo.environment[name]
}
