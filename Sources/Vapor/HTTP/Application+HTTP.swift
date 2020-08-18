extension Application {
    public var http: HTTP {
        .init(application: self)
    }

    public struct HTTP {
        public let application: Application
    }
}
