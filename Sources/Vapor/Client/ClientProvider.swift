#if os(Linux)
import FoundationNetworking
#else
import Foundation
#endif

internal final class ClientProvider: Provider {
    init() { }

    func register(_ s: inout Services) {
        s.register(HTTPClient.Configuration.self) { c in
            return .init()
        }
        s.register(WebSocketClient.Configuration.self) { c in
            return .init()
        }
        s.register(Client.self) { c in
            return try c.make(DefaultClient.self)
        }
        s.register(FoundationClient.self) { c in
            return try FoundationClient(c.make(), on: c.eventLoop)
        }
        s.register(URLSession.self) { c in
            return try URLSession(configuration: c.make())
        }
        s.register(URLSessionConfiguration.self) { c in
            return .default
        }
        s.singleton(DefaultClient.self) { c in
            return try .init(
                httpConfiguration: c.make(),
                webSocketConfiguration: c.make(),
                on: c.eventLoop
            )
        }
    }

    func willShutdown(_ c: Container) {
        do {
            try c.make(DefaultClient.self).syncShutdown()
        } catch {
            Logger(label: "codes.vapor.client-provider").error("Could not shutdown Client: \(error)")
        }
    }
}
