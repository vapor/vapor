public protocol SessionDriver: class {
    func valueForKey(key: String, inSessionIdentifiedBy sessionIdentifier: String) -> String?
    func setValue(value: String?, forKey key: String, inSessionIdentifiedBy sessionIdentifier: String)
    func createSessionIdentifier() -> String
    func destroySessionIdentifiedBy(sessionIdentifier: String)
}
