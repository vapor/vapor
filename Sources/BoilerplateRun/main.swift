import Boilerplate

try Boilerplate.app(.detect())
    .run().wait()
    .cleanup()
