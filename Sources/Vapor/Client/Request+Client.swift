extension Request {
    public var client: Client {
        self.application.client.logging(to: self.logger).allocating(to: self.byteBufferAllocator)
    }
}
