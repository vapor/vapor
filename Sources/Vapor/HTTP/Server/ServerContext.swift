/// Everything the HTTP server needs from the application
///
/// The `FreezableType`s here are references to the same types the application holds so any changes are passed through
package final class ServerContext: Sendable {
    let configuration: FreezableType<ServerConfiguration>
    let routes: FreezableType<RouteStorage>
    let middlewares: FreezableType<Middlewares>
    let responder: Application.ServiceOptionType<any Responder>

    package let contentConfiguration: ContentConfiguration

    init(
        configuration: FreezableType<ServerConfiguration>,
        routes: FreezableType<RouteStorage>,
        middlewares: FreezableType<Middlewares>,
        responder: Application.ServiceOptionType<any Responder>,
        contentConfiguration: ContentConfiguration
    ) {
        self.configuration = configuration
        self.routes = routes
        self.middlewares = middlewares
        self.responder = responder
        self.contentConfiguration = contentConfiguration
    }

    /// The default max body size for routes that do not set one of their own.
    var defaultMaxBodySize: ByteCount {
        self.routes.value.defaultMaxBodySize
    }

    /// Builds the responder chain.
    package func makeResponder() -> any Responder {
        switch self.responder {
        case .default:
            DefaultResponder(
                routes: self.routes.value,
                middleware: self.middlewares.value.resolve()
            )
        case .provided(let provided):
            provided
        }
    }
}
