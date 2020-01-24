import Vapor

var env = try Environment.detect()
try LoggingSystem.bootstrap(from: &env)

let app = try Application(env)
defer { app.shutdown() }

try configure(app)

try app.run()
