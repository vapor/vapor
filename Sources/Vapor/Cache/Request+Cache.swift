extension Request {
    public var cache: Cache {
        self.application.cache.for(self)
    }
}
