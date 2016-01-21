Route.get("/heartbeat") { request in 
	return ["lub": "dub"]
}

Route.resource("users", controller: Controller())

Route.get("/text") { request in 
	return "Hello"
}

let server = Server()
server.run(port: 8080)