extension Request {
    public struct Services {
        public let request: Request
        init(request: Request) {
            self.request = request
        }
    }

    public var services: Services {
        Services(request: self)
    }
}
