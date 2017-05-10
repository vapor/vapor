extension String {
    /**
         Hydrates from environment if has leading `$`. If contains `:`, represents fallback.
            
            $PORT:8080

         Checks first if `PORT` env variable is set, then loads `8080`

         If no fallback, and no env value, returns nil
    */
    internal func hydratedEnv() -> String? {
        guard hasPrefix("$") else { return self }
        let components = self.makeBytes()
            .dropFirst()
            .split(separator: .colon, maxSplits: 1, omittingEmptySubsequences: true)
            .map({ $0.makeString() })

        return components.first.flatMap(Env.get)
            ?? components[safe: 1]
    }
}
