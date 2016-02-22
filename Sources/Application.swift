import Foundation

#if os(Linux)
	import Glibc
#endif

public class Application {
	public static let VERSION = "0.1.9"

	/**
		Flag indicating whether or not the
		application and it’s providers have
		been booted yet
	*/
	public private(set) var booted = false

	/**
		The router driver is responsible
		for returning registered `Route` handlers
		for a given request.
	*/
	public var router: RouterDriver

	/**
		The server driver is responsible
		for handling connections on the desired port.
		This property is constant since it cannot
		be changed after the server has been booted.
	*/
	public let server: ServerDriver

	/**
		`Middleware` will be applied in the order
		it is set in this array.

		Make sure to append your custom `Middleware`
		if you don't want to overwrite default behavior.
	*/
	public var middleware: [Middleware]


	/**
		Provider classes that have been registered
		with this application
	*/
	private var providers = Array<Provider.Type>()

	/**
		The work directory of your application is
		the directory in which your Resources, Public, etc
		folders are stored. This is normally `./` if
		you are running Vapor using `.build/xxx/App`
	*/
	public static var workDir = "./" {
		didSet {
			if !self.workDir.hasSuffix("/") {
				self.workDir += "/"
			}
		}
	}

	public convenience init(_ providers: [Provider.Type] = []) {
		self.init(providers: providers)
	}

	/**
		Initialize the Application instance with various optional overrides.

		- Parameter server: Instance of ServerDriver, optionally defaulting to SocketServer
		- Parameter router: Instance of RouterDriver, optionally defaulting to NodeRouter
		- Parameter providers: Optional list of providers to register
	*/
	public init(server: ServerDriver = SocketServer(), router: RouterDriver = NodeRouter(), providers: [Provider.Type] = []) {
		self.router = router

		self.middleware = [
			SessionMiddleware()
		]

		self.server = server
		self.server.delegate = self

		self.register(providers)
	}

	public func register(providers: [Provider.Type]) {
		for provider in providers {
			self.register(provider)
		}
	}

	public func register(provider: Provider.Type) {
		guard !self.hasProvider(provider) else {
			return
		}

		self.providers.append(provider)

		if self.booted {
			self.bootProvider(provider)
		}
	}

	public func hasProvider(provider: Provider.Type) -> Bool {
		for value in self.providers {
			if value == provider {
				return true
			}
		}

		return false
	}

	public func boot() {
		if self.booted {
			return
		}

		for provider in self.providers {
			self.bootProvider(provider)
		}

		self.booted = true
	}

	public func bootProvider(provider: Provider.Type) {
		provider.boot(self)
	}

	/**
		Boots the chosen server driver and
		runs on the supplied port.
	*/
	public func start(port inPort: Int = 80) {
		self.boot()

		self.registerRoutes()

		var port = inPort

		//grab process args
		for argument in Process.arguments {
			if argument.hasPrefix("--workDir=") {
				let workDirString = argument.split("=")[1]
				self.dynamicType.workDir = workDirString
				print("Work dir override: \(workDirString)")
			} else if argument.hasPrefix("--port=") {
				let portString = argument.split("=")[1]
				if let portInt = Int(portString) {
					print("Port override: \(portInt)")
					port = portInt
				}
			}
		}

		do {
			try self.server.boot(port: port)

			print("Server has started on port \(port)")

			self.loop()
		} catch {
			print("Server start error: \(error)")
		}
	}

	/**
		Starts an infinite loop to keep the server alive while it
		waits for inbound connections.
	*/
	func loop() {
		#if os(Linux)
			while true {
				sleep(1)
			}
		#else
			NSRunLoop.mainRunLoop().run()
		#endif
	}

	/**
		Registers all routes from the `Route` interface
		into the current `RouterDriver`.
	*/
	func registerRoutes() {
		for route in Route.routes {
			self.router.register(hostname: route.hostname, method: route.method, path: route.path) { request in
				let response: Response

				do {
					response = try route.closure(request: request).response()
				} catch View.Error.InvalidPath {
					response = Response(status: .NotFound, text: "View not found")
				} catch {
					response = Response(error: "Server Error: \(error)")
				}

				return response
			}
		}
	}

}

extension Application: ServerDriverDelegate {

	public func serverDriverDidReceiveRequest(request: Request) -> Response {
		var handler: Request -> Response

		// Check in routes
		if let routerHandler = router.route(request) {
			handler = routerHandler
		} else {
			// Check in file system
			let filePath = self.dynamicType.workDir + "Public" + request.path

			let fileManager = NSFileManager.defaultManager()
			var isDir: ObjCBool = false

			if fileManager.fileExistsAtPath(filePath, isDirectory: &isDir) {
				// File exists
				if let fileBody = NSData(contentsOfFile: filePath) {
					var array = [UInt8](count: fileBody.length, repeatedValue: 0)
					fileBody.getBytes(&array, length: fileBody.length)

					return Response(status: .OK, data: array, contentType: .Text)
				} else {
					handler = { _ in
						return Response(error: "Could not open file.")
					}
				}
			} else {
				// Default not found handler
				handler = { _ in
					return Response(status: .NotFound, text: "Page not found")
				}
			}
		}

		// Loop through middlewares in order
		for middleware in self.middleware {
			handler = middleware.handle(handler)
		}

		let response = handler(request)
		return response
	}

}
