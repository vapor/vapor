extension Request {
    public var client: any Client {
        self.application.client.logging(to: self.logger).allocating(to: self.byteBufferAllocator)
    }
}
