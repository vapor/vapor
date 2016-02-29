public protocol SessionDriver: class {
    func newSessionIdentifier() -> String
    func valueFor(key key: String, inSession session: Session) -> String?
    func set(value value: String?, forKey key: String, inSession session: Session)
    func destroy(session session: Session)
}
