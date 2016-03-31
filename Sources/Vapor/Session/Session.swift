/**
    Use the Session class to store sensitive
    information for individual users of your application
    such as API keys or login tokens.

    Access the current Application's Session using
    `app.session`.
*/
public class Session {

    public var identifier: String?
    var driver: SessionDriver
    public var enabled: Bool

    public init(driver: SessionDriver) {
        self.driver = driver
        enabled = false
    }

    init(identifier: String, driver: SessionDriver) {
        self.driver = driver
        self.identifier = identifier
        enabled = true
    }

    public func destroy() {
        if let i = identifier {
            identifier = nil
            driver.destroy(i)
        }
    }

    public subscript(key: String) -> String? {
        get {
            guard let i = identifier else {
                return nil
            }

            return driver.valueFor(key: key, identifier: i)
        }
        set {
            let i: String

            if let existingIdentifier = identifier {
                i = existingIdentifier
            } else {
                i = driver.makeSessionIdentifier()
                identifier = i
            }

            driver.set(newValue, forKey: key, identifier: i)
        }
    }
}
