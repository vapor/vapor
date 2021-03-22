
// MARK: - Sessions

extension SessionData {
    @available(*, deprecated, message: "use SessionData.init(initialData:)")
    public init(_ data: [String: String]) { self.init(initialData: data) }
}
