
public class Session {

	public static var driver: SessionDriver = MemorySessionDriver()

    var sessionIdentifier: String?

	init() {
		//do nothing
	}

	public func destroy() {
        guard let sessionIdentifier = sessionIdentifier else {
            Log.warning("Unable to destroy the session: The session has not be registered yet")
            return
        }

        Session.driver.destroySessionIdentifiedBy(sessionIdentifier)
	}

    public subscript(key: String) -> String? {
        get {
            guard let sessionIdentifier = sessionIdentifier else {
                Log.warning("Unable to read a value for '\(key)': The session has not be registered yet")
                return nil
            }

            return Session.driver.valueForKey(key, inSessionIdentifiedBy: sessionIdentifier)
        }

        set(newValue) {
            guard let sessionIdentifier = sessionIdentifier else {
                Log.warning("Unable to store a value for '\(key)': The session has not be registered yet")
                return
            }

            Session.driver.setValue(newValue, forKey: key, inSessionIdentifiedBy: sessionIdentifier)
        }
    }
}
