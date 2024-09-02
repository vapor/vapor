extension Application {
    public var routes: Routes {
        get async {
            if let existing = self.storage[RoutesKey.self] {
                return existing
            } else {
                let new = Routes()
                await self.storage.set(RoutesKey.self, to: new)
                return new
            }
        }
    }

    private struct RoutesKey: StorageKey {
        typealias Value = Routes
    }
}
