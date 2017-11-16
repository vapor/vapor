import Boilerplate
import Vapor

let config = Config.default()
let env = Environment.detect()
let services = Services.default()

try Boilerplate.configure(config, env, services)

let app = try Application(
    config: config,
    environment: env,
    services: services
)

try Boilerplate.boot(app)

try app.run()

