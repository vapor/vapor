//import Service
//
//extension Config {
//    internal func merged(with sub: Config) -> Config? {
//        guard let object = self.dictionary, let value = sub.dictionary else { return nil }
//        var mutable = object
//        mutable.merge(with: value)
//        return .dictionary(mutable)
//    }
//}
//
//extension KeyAccessible where Key == String, Value == Config {
//    fileprivate mutating func merge(with sub: [String: Config]) {
//        sub.forEach { key, value in
//            if let existing = self[key] {
//                // If something exists, and is object, merge. Else leave what's there
//                guard let merged = existing.merged(with: value) else { return }
//                self[key] = merged
//            } else {
//                self[key] = value
//            }
//        }
//    }
//}

