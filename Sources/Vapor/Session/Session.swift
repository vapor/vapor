
public class Session {

    public static var driver: SessionDriver = MemorySessionDriver()

    var sessionIdentifier: String?

	init() {
		//do nothing
	}

	public func destroy() {
        Session.driver.destroy(self)
	}

    public subscript(key: String) -> String? {
        get {
            return Session.driver.valueFor(key: key, inSession: self)
        }

        set {
            Session.driver.set(newValue, forKey: key, inSession: self)
        }
    }
}
