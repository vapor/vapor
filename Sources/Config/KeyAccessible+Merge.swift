extension KeyAccessible where Key == String, Value == Node {
    mutating func merge(with sub: [String: Node]) {
        sub.forEach { key, value in
            if let existing = self[key] {
                // If something exists, and is object, merge. Else leave what's there
                guard let merged = existing.merged(with: value) else { return }
                self[key] = merged
            } else {
                self[key] = value
            }
        }
    }
}
