public protocol SessionDriver: class {
    var randomSessionIdentifier: String
    func valueForKey(key: String, inSessionIdentifiedBy sessionIdentifier: String) -> String?
    func setValue(value: String?, forKey key: String, inSessionIdentifiedBy sessionIdentifier: String)
    func destroySessionIdentifiedBy(sessionIdentifier: String)
}
