import Configs

private let providersKey = "vapor:providers"

extension Config {
    var providers: [Provider] {
        get { return storage[providersKey] as? [Provider] ?? [] }
        set { storage[providersKey] = newValue }
    }
    
    public mutating func addProvider<P: Provider>(_ provider: P) throws {
        guard !providers.contains(where: { type(of: $0) == P.self }) else {
            return
        }
        try provider.boot(&self)
        providers.append(provider)
    }
    
    public mutating func addProvider<P: Provider>(_ provider: P.Type) throws {
        let p = try provider.init(config: self)
        try addProvider(p)
    }
}
