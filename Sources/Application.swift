public class Application {
	public static let VERSION = "0.1.9"

	private var providers = Array<Provider>()
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

	public func register<T: Provider>(provider: T.Type) -> T {
		if let registered = self.getProvider(provider) {
			return registered
		}

		let provider = provider.init(application: self)
		provider.register()

		if self.booted {
			self.bootProvider(provider)
		}

		return provider
	}

	public func getProvider<T: Provider>(provider: T.Type) -> T? {
		for value in self.providers {
			if value.dynamicType == provider {
				return value as? T
			}
		}

		return nil
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

	public func bootProvider(provider: Provider) {
		provider.boot()
	}

}
