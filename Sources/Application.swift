public class Application {
	public static let VERSION = "0.1.9"

	private var providers = Array<Provider.Type>()
	public private(set) var booted = false
	public let server: Server

	public convenience init(_ providers: [Provider.Type] = []) {
		self.init(serverDriver: SocketServer(), providers: providers)
	}

	public init(serverDriver: ServerDriver, providers: [Provider.Type] = []) {
		self.server = Server(driver: serverDriver)
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

	public func start(port: Int? = nil) {
		self.boot()

		if let port = port {
			self.server.run(port: port)
		} else {
			self.server.run()
		}
	}

	public func bootProvider(provider: Provider.Type) {
		provider.boot(self)
	}

}
