import NIOCore
import NIOConcurrencyHelpers
import Logging

extension Application.Servers.Provider {
    public static var httpNew: Self {
        .init {
            $0.servers.use { app in
                if let existing = app.storage[ServerKey.self] {
                    return existing
                }
                let adapter = NIOHTTPServerAdapter(application: app)
                app.storage[ServerKey.self] = adapter
                return adapter
            }
        }
    }
}

private struct ServerKey: StorageKey, Sendable {
    typealias Value = NIOHTTPServerAdapter
}
