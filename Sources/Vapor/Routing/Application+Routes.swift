extension Application {
    public var routes: Routes {
        if let existing = self.storage[RoutesKey.self] {
            return existing
        } else {
            let new = Routes()
            self.storage[RoutesKey.self] = new
            return new
        }
    }

    private struct RoutesKey: StorageKey {
        typealias Value = Routes
    }
}
