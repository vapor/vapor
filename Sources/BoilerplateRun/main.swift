import Boilerplate

let app = try Boilerplate.app(.detect())
try app.run().wait()
try app.runningServer?.onClose.wait()
