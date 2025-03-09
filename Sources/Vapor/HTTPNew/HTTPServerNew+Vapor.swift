import HTTPServerNew
import NIOCore

extension HTTPServer: Server {
    #warning("Consider now allowing address to be set in the start")
    public func start(address: Vapor.BindAddress?) async throws {
        if let address {
            guard case var .initial(childChannelSetup, configurtion, onRunning) = self.state else {
#warning("Fix this")
                throw Abort(.notImplemented)
            }
            let newAddress: HTTPServerNew.BindAddress
            switch address {
            case .hostname(let hostname, let port):
                newAddress = .hostname(hostname ?? "127.0.0.1", port: port ?? 8080)
            case .unixDomainSocket(let path):
                newAddress = .unixDomainSocket(path: path)
            }
            #if canImport(Network)
            let newConfiguration = ServerConfiguration(address: newAddress, serverName: configurtion.serverName, backlog: configurtion.backlog, reuseAddress: configurtion.reuseAddress, availableConnectionsDelegate: configurtion.availableConnectionsDelegate, tlsOptions: configurtion.tlsOptions)
            #else
            let newConfiguration = ServerConfiguration(address: address, serverName: configurtion.serverName, backlog: configurtion.backlog, reuseAddress: configurtion.reuseAddress, availableConnectionsDelegate: configurtion.availableConnectionsDelegate)
            #endif
            self.state = .initial(childChannelSetup: childChannelSetup, configuration: newConfiguration, onServerRunning: onRunning)
        }

        try await self.run()
    }

    public func shutdown() async throws {
        try await self.shutdownGracefully()
    }
}
