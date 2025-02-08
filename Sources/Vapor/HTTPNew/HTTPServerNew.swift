import HTTPServerNew
import NIOCore

extension HTTPServer {

}

//extension HTTPServerNew.HTTPServer: @preconcurrency Server {
//    public func start(address: BindAddress?) async throws {
//        try await self.run()
//    }
//    
//    public var onShutdown: NIOCore.EventLoopFuture<Void> {
//        fatalError()
//    }
//    
//    public func shutdown() async throws {
//        try await self.shutdownGracefully()
//    }
//}
