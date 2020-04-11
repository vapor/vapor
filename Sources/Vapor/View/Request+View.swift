extension Request {
    public var view: ViewRenderer {
        self.application.view.for(self)
    }
}
