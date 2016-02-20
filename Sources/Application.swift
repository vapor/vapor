public func app() -> Application {
	return Application.getInstance()
}

public class Application {
	public static let VERSION = "0.1.9"
	private static var instance: Application?

	public private(set) var booted = false
	public let server: Server

	public convenience init() {
		self.init(serverDriver: SocketServer())
	}

	public init(serverDriver: ServerDriver) {
		self.server = Server(driver: serverDriver)
		self.dynamicType.setInstance(self)
	}

	public static func getInstance() -> Application {
		if let instance = self.instance {
			return instance
		}

		let instance = Application()
		self.setInstance(instance)
		return instance
	}

	public static func setInstance(instance: Application) {
		self.instance = instance
	}

	public func boot() {
		if self.booted {
			return
		}

		self.booted = true
	}

}
