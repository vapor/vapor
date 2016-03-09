
public class Session {

    public internal(set) var identifier: String?
    var driver: SessionDriver?

	init() {
		//do nothing
	}

	public func destroy() {
        driver?.destroy(self)
	}

    public subscript(key: String) -> String? {
        get {
            return driver?.valueFor(key: key, inSession: self)
        }

        set {
            driver?.set(newValue, forKey: key, inSession: self)
        }
    }
}
