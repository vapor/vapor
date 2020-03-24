extension Application {
    private struct UserInfoKey: StorageKey {
        typealias Value = [AnyHashable: Any]
    }

    @available(*, deprecated, message: "Use storage instead.")
    public var userInfo: [AnyHashable: Any] {
        get {
            self.storage[UserInfoKey.self] ?? [:]
        }
        set {
            self.storage[UserInfoKey.self] = newValue
        }
    }
}

extension Request {
    private struct UserInfoKey: StorageKey {
        typealias Value = [AnyHashable: Any]
    }

    @available(*, deprecated, message: "Use storage instead.")
    public var userInfo: [AnyHashable: Any] {
        get {
            self.storage[UserInfoKey.self] ?? [:]
        }
        set {
            self.storage[UserInfoKey.self] = newValue
        }
    }
}
