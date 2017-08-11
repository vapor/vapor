import Service

extension Config {
    /// Anywhere we find a key or value that is a string w/ a leading `$`,
    /// we will look for it in environment, or treat as `nil`.
    ///
    /// If there is a `:`, all content following colon will be treated as fallback.
    ///
    /// For example:
    ///
    /// ["port": "$PORT:8080"]
    ///
    /// If `PORT` has value, the node will be `["port": "<value of port>"]
    /// If `PORT` has NO value, the node will be `["port": "8080"]`
    ///
    /// Another example:
    ///
    /// ["key": "$MY_KEY"]
    ///
    /// If `MY_KEY` has value, the node will be `["key": "<value of key>"]
    /// If `PORT` has NO value, the node will be nil
    internal func environmentVariablesResolved() -> Config {
        switch self {
        case .dictionary(let obj):
            return .dictionary(obj.mapValues { $0.environmentVariablesResolved() })
        case .array(let arr):
            return .array(arr.flatMap { $0.environmentVariablesResolved() })
        case .string(let str):
            guard let hydrated = str.hydratedEnv() else {
                return .null
            }
            return .string(hydrated)
        default:
            return self
        }
    }
}


extension String {
    /// Hydrates from environment if has leading `$`. If contains `:`, represents fallback.
    ///
    /// $PORT:8080
    ///
    /// Checks first if `PORT` env variable is set, then loads `8080`
    ///
    /// If no fallback, and no env value, returns nil
    fileprivate func hydratedEnv() -> String? {
        guard hasPrefix("$") else { return self }
        let components = self.makeBytes()
            .dropFirst()
            .split(separator: .colon, maxSplits: 1, omittingEmptySubsequences: true)
            .map({ $0.makeString() })

        return components.first.flatMap(Env.get)
            ?? components[safe: 1]
    }
}
