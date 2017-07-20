public protocol ProviderFactory {
    var providerType: Provider.Type { get }
    func makeProvider(with config: Config) throws -> Provider?
}

struct TypeProviderFactory<P: Provider>: ProviderFactory {
    var providerType: Provider.Type {
        return P.self
    }

    func makeProvider(with config: Config) throws -> Provider? {
        return try P(config: config)
    }

    init(_ p: P.Type = P.self) { }
}

public struct BasicProviderFactory<P: Provider>: ProviderFactory {
    public typealias ProviderFactoryClosure<P: Provider> = (Config) throws -> P?

    public let closure: ProviderFactoryClosure<P>

    public var providerType: Provider.Type {
        return P.self
    }

    init(_ p: P.Type = P.self, factory closure: @escaping ProviderFactoryClosure<P>) {
        self.closure = closure
    }

    public func makeProvider(with config: Config) throws -> Provider? {
        return try closure(config)
    }
}
