import Configs

extension KeyAccessible where Key == String, Value == Config {
    mutating func merge(with sub: [String: Config]) {
        sub.forEach { key, value in
            if var existing = self[key] {
                // If something exists, and is object, merge. Else leave what's there
                guard let merged = existing.merged(with: value) else {
                    return
                }
                self[key] = merged
            } else {
                self[key] = value
            }
        }
    }
}
