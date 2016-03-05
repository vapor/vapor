public protocol SessionDriver: class {
    func makeSessionIdentifier() -> String
    func valueFor(key key: String, inSession session: Session) -> String?
    func set(value: String?, forKey key: String, inSession session: Session)
    func destroy(session: Session)
}
