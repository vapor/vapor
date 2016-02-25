import Foundation

protocol SessionDriver {
	var sessions: [String: Session] { get set }
}

public class Session {

	public enum DriverType {
		case File, Memory
	}
	public static var type: DriverType = .Memory {
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
	public var data: [String: String] = [:] {
		didSet {
			if self.key == nil {
                
				var key = "\(NSDate().timeIntervalSinceNow)"
                key += "v@p0r"
                key += "\(Int.random(min: 0, max: 9999))"
                key += "s3sS10n"
                key += "\(Int.random(min: 0, max: 9999))"
                key += "k3y"
                key += "\(Int.random(min: 0, max: 9999))"
                
                key = Hash.make(key)
                
				self.key = key
				Session.driver.sessions[key] = self
			}
		}
	}

}