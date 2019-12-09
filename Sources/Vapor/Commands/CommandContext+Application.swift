extension CommandContext {
    public var application: Application {
        get {
            guard let application = self.userInfo["application"] as? Application else {
                fatalError("Application not set on context")
            }
            return application
        }
        set {
            self.userInfo["application"] = newValue
        }
    }
}
