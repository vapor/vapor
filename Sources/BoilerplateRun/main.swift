import Boilerplate

let a = try app(.detect())
try a.run().wait()
print(a.runningServer)
try a.runningServer?.onClose.wait()
