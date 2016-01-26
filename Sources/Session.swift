protocol SessionDriver {
	var sessions: [String: Session] { get set }
}

public class Session {

	public enum Type {
		case File, Memory
	}
	public static var type: Type = .Memory {
		didSet {
			switch self.type {
				case .Memory:
					self.driver = MemorySessionDriver()
				case .File:
					fatalError("File driver not yet supported")
			}
		}
	}
	static var driver: SessionDriver = MemorySessionDriver()

	public static func start(request: Request) {
		if let key = request.cookies["vapor-session"] {
			if let session = self.driver.sessions[key] {
				request.session = session
			} else {
				request.session.key = key
				self.driver.sessions[key] = request.session
			}
		}
	}

	public static func close(request request: Request, response: Response) {
		if let key = request.session.key {
			response.cookies["vapor-session"] = key
		} 
	}

	init() {
		//do nothing
	}

	public func destroy() {
		if let key = self.key {
			Session.driver.sessions.removeValueForKey(key)
		}
	}

	var key: String?
	var data: [String: String] = [:] {
		didSet {
			if self.key == nil {
				let key = "12931923912" //TODO: generate random key
				self.key = key
				Session.driver.sessions[key] = self
			}
		}
	}

}