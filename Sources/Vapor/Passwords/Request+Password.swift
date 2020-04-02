extension Request {
    public var password: AsyncPasswordVerifier {
        self.application.password.async(on: application.threadPool, hopTo: eventLoop)
    }
}
