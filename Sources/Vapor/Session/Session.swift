/**
    Use the Session class to store sensitive
    information for individual users of your application
    such as API keys or login tokens.

    Access the current Application's Session using
    `app.session`.
*/
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
        enabled = false
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
