/**
    Session storage engines that conform to this
    protocol can be used to power the Session class.
*/
public protocol SessionDriver: class {
    var app: Application { get }
    
    func makeSessionIdentifier() -> String
    func valueFor(key key: String, identifier: String) -> String?
    func set(value: String?, forKey key: String, identifier: String)
    func destroy(identifier: String)
}
