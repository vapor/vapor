extension Application {
    public var http: HTTP {
        .init(application: self)
    }

    public struct HTTP: Sendable {
        public let application: Application
    }
}
