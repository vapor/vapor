import NIOConcurrencyHelpers

extension Application {
    public func registry<ID: Hashable & Sendable, Value: Sendable>(for name: String) -> Registry<ID, Value> {
        self.registries.get(name)
    }

    var registries: Registries {
        .init(application: self)
    }

    struct Registries: Sendable {
        final class Storage: Sendable {
            let registries: NIOLockedValueBox<[String: any Sendable]>
            init() {
                self.registries = .init([:])
            }
        }

        struct Key: StorageKey {
            typealias Value = Storage
        }

        let application: Application

        var storage: Storage {
            if let existing = self.application.storage[Key.self] {
                return existing
            }
            let new = Storage()
            self.application.storage[Key.self] = new
            return new
        }

        func get<ID: Hashable & Sendable, Value: Sendable>(_ name: String) -> Registry<ID, Value> {
            self.storage.registries.withLockedValue { dict in
                if let existing = dict[name] {
                    guard let typed = existing as? Registry<ID, Value> else {
                        fatalError(
                            "Registry '\(name)' already exists with a different type. "
                            + "Expected Registry<\(ID.self), \(Value.self)>, "
                            + "found \(type(of: existing))."
                        )
                    }
                    return typed
                }
                let new = Registry<ID, Value>()
                dict[name] = new
                return new
            }
        }
    }
}

extension Request {
    public func registry<ID: Hashable & Sendable, Value: Sendable>(for name: String) -> Registry<ID, Value> {
        self.application.registry(for: name)
    }
}
