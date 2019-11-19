import Vapor

let app = try Application(.detect())
defer { app.shutdown() }
try configure(app)
try app.run()
