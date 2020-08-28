import Foundation
import Logging
import Vapor

let isLoggingConfigured: Bool = {
    var env = Environment.detect(default: .testing)
    try! LoggingSystem.bootstrap(from: &env)
    return true
}()

func env(_ name: String) -> String? {
    ProcessInfo.processInfo.environment[name]
}
