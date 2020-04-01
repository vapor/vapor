extension Request {
    public var client: Client {
        self.application.clients.client.for(self)
    }
}
