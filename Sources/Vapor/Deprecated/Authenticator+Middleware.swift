extension RequestAuthenticator {
    @available(*, deprecated, message: "uthenticator itself is now a middleware.")
    public func middleware() -> Middleware {
        self
    }
}

extension SessionAuthenticator {
    @available(*, deprecated, message: "Authenticator itself is now a middleware.")
    public func middleware() -> Middleware {
        self
    }
}
