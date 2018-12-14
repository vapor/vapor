import Boilerplate

let a = try app(.detect())
try a.run().wait()
try a.runningServer?.onClose.wait()
