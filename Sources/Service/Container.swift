import Async

public protocol Container: Extendable {
    var config: Config { get }
    var environment: Environment { get }
    var services: Services { get }
}
