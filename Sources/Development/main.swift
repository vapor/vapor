import Vapor

// normally this would be in a separate target
try Application(
    environment: .detect(),
    delegate: Development()
).run()
