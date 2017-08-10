import Configs

extension Config {
    internal mutating func merged(with sub: Config) -> Config? {
        guard let main = self.dictionary, let sub = sub.dictionary else {
            return nil
        }
        var mutable = main
        for (key, val) in sub {
            mutable[key] = val
        }
        return .dictionary(mutable)
    }
}
