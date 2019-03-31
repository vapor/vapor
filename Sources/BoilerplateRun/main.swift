import Boilerplate
import Dispatch

do {
    let app = try Boilerplate.app(.detect())
    
    DispatchQueue.global().async {
        sleep(2)
        app.running!.stop()
    }
    
    try app.execute().wait()
}
