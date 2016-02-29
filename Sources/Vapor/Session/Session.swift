
public class Session {

    public static var driver: SessionDriver = MemorySessionDriver()

    var sessionIdentifier: String?

	init() {
		//do nothing
	}

	public func destroy() {
        Session.driver.destroy(session: self)
	}

    public subscript(key: String) -> String? {
        get {
            return Session.driver.valueFor(key: key, inSession: self)
        }

        set {
            Session.driver.set(value: newValue, forKey: key, inSession: self)
        }
    }
}
