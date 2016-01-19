import Glibc
import Swifter

let server = HttpServer()

do {

	server["/heartbeat"] = { request in 
	    return .OK(.Html("{lub:dub}"))
	}

	let port: in_port_t = 80
	try server.start(port)
	print("Server has started on port \(port)")

	while true {
		sleep(1)
	}
} catch {
	print("Server start error: \(error)")
}

