extension Request {
    public var cache: any Cache {
        self.application.cache.for(self)
    }
}
