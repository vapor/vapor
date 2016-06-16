extension HTTP.Version {
    init<S: Sequence where S.Iterator.Element == Byte>(_ bytes: S) throws {
        // ["HTTP", "1.1"]
        let comps = bytes.split(separator: .forwardSlash, maxSplits: 1, omittingEmptySubsequences: true)
        guard comps.count == 2 else { throw HTTP.Parser.Error.invalidVersion }
        let version = comps[1].split(separator: .period, maxSplits: 1, omittingEmptySubsequences: true)
        guard
            version.count == 2,
            let major = version.first?.decimalInt,
            let minor = version.last?.decimalInt
            else { throw HTTP.Parser.Error.invalidVersion }
        self = Version(major: major, minor: minor)
    }
}
