import Boilerplate

let app = try BoilerplateApp(env: .detect())
try app.run().wait()
try app.cleanup()
