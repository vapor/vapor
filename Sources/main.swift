import Glibc
import Swifter

let server = HttpServer()

server["/"] = { request in
	return .OK(.Html("welcome"))
}

server["/heartbeat"] = { request in 
    return .OK(.Html("{lub:dub}"))
}

do {
	let port: in_port_t = 8080
	try server.start(port)
	print("Server has started on port \(port)")

	while true {
		sleep(1)
	}
} catch {
	print("Server start error: \(error)")
}

