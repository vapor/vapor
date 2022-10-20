extension Application {
    public struct Services {
        public let application: Application
    }

    public var services: Services {
        .init(application: self)
    }
}
