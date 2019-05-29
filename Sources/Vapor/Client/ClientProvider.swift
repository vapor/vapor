internal final class ClientProvider: Provider {
    init() { }

    func register(_ s: inout Services) {
        s.register(HTTPClient.Configuration.self) { c in
            return .init()
        }
        s.register(WebSocketClient.Configuration.self) { c in
            return .init()
        }
        s.singleton(Client.self) { c in
            return try .init(
                httpConfiguration: c.make(),
                webSocketConfiguration: c.make(),
                on: c.eventLoop
            )
        }
    }

    func willShutdown(_ c: Container) {
        do {
            try c.make(Client.self).syncShutdown()
        } catch {
            Logger(label: "codes.vapor.client-provider").error("Could not shutdown Client: \(error)")
        }
    }
}
