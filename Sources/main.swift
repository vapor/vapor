import Glibc
import Swifter

let server = HttpServer()

do {

	server["/heartbeat"] = { request in 
	    return .OK(.Html("{lub:dub}"))
	}

	try server.start()
	print("Server has started on port 8080")

	while true {
		sleep(1)
	}
} catch {
	print("Server start error: \(error)")
}

