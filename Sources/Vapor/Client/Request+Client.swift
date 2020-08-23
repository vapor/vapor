extension Request {
    public var client: Client {
        self.application.client.delegating(to: self.eventLoop, logger: self.logger)
    }
}
