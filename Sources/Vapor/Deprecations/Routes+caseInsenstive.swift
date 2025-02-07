extension Routes {
    @available(*, deprecated, renamed: "caseInsensitive")
    public var caseInsenstive: Bool {
        get {
            caseInsensitive
        }
        set {
            caseInsensitive = newValue
        }
    }
}
