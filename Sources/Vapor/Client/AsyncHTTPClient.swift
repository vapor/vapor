import AsyncHTTPClient

public struct AsyncHTTPClient: Client {
    public let eventLoop: EventLoop
    let application: Application
    
    public var driver: HTTPClient {
        if let existing = self.application.storage[ClientKey.self] {
            return existing
        } else {
            let lock = self.application.locks.lock(for: ClientKey.self)
            lock.lock()
            defer { lock.unlock() }
            if let existing = self.application.storage[ClientKey.self] {
                return existing
            }
            let new = HTTPClient(
                eventLoopGroupProvider: .shared(self.application.eventLoopGroup),
                configuration: self.configuration
            )
            self.application.storage.set(ClientKey.self, to: new) {
                try $0.syncShutdown()
            }
            return new
        }
    }

    public var configuration: HTTPClient.Configuration {
        get {
            self.application.storage[ConfigurationKey.self] ?? .init()
        }
        nonmutating set {
            if self.application.storage.contains(ClientKey.self) {
                self.application.logger.warning("Cannot modify client configuration after client has been used")
            } else {
                self.application.storage[ConfigurationKey.self] = newValue
            }
        }
    }
    
    struct ClientKey: StorageKey, LockKey {
        typealias Value = HTTPClient
    }
    
    struct ConfigurationKey: StorageKey {
        typealias Value = HTTPClient.Configuration
    }
    
    public func `for`(_ request: Request) -> Client {
        AsyncHTTPClient(eventLoop: request.eventLoop, application: self.application)
    }

    public func send(_ request: ClientRequest) -> EventLoopFuture<ClientResponse> {
        return self.driver.send(request, eventLoop: .delegate(on: self.eventLoop))
    }
}
