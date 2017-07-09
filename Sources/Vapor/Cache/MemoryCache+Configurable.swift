import Cache

extension MemoryCache: Service {
    public convenience init?(_ drop: Droplet) throws {
        self.init()
    }
    
    public var name: String {
        return "memory"
    }
}
