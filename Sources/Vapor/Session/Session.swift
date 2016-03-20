
public class Session {

    public let identifier: String
    var driver: SessionDriver
    public var enabled: Bool

    public init(driver: SessionDriver) {
        self.driver = driver
        identifier = driver.makeSessionIdentifier()
        enabled = false
    }

    init(identifier: String, driver: SessionDriver) {
        self.driver = driver
        self.identifier = identifier
        enabled = true
	}

	public func destroy() {
        driver.destroy(self)
	}

    public subscript(key: String) -> String? {
        get {
            return driver.valueFor(key: key, inSession: self)
        }
        set {
            enabled = true
            driver.set(newValue, forKey: key, inSession: self)
        }
    }
}
