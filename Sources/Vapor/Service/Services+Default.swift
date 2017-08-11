import Console
import Sessions
import Cache
import Service
import Routing

public typealias Config = Service.Config

extension Services {
    public static func `default`() -> Services {
        var services = Services()

        // console
        services.register(Terminal.self)

        // log
        services.register(ConsoleLogger.self)

        // rotuer
        services.register(Router.self)

        // cache
        services.register(MemoryCache.self)
        services.register(CacheSessions.self)

        // middleware
        services.register(SessionsMiddleware.self)
        services.register(ErrorMiddleware.self)
        services.register(FileMiddleware.self)
        services.register(DateMiddleware.self)
        services.register(CORSMiddleware.self)

        // cipher
        services.register(CryptoCipher.self)

        // hash
        services.register(CryptoHasher.self)
        services.register(BCryptHasher.self)

        // engine
        services.register(ClientFactory<EngineClient>.self)
        services.register(ClientFactory<FoundationClient>.self)
        services.register(ServerFactory<EngineServer>.self)

        // commands
        services.register(DumpConfig.self)
        services.register(Serve.self)
        services.register(RouteList.self)
        services.register(ProviderInstall.self)

        // sessions
        services.register(MemorySessions.self)
        services.register(CacheSessions.self)

        // view
        services.register(StaticViewRenderer.self)

        // mail
        services.register(Mailgun.self)
        
        return services
    }
}
