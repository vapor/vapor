extension Request {
    public var client: Client {
        self.application.client.delegating(to: self.eventLoop).logging(to: self.logger).allocating(to: self.byteBufferAllocator)
    }
}
