extension HTTP.Version {
    init<S: Sequence where S.Iterator.Element == Byte>(_ bytes: S) throws {
        // ["HTTP", "1.1"]
        let comps = bytes.split(separator: .forwardSlash, maxSplits: 1, omittingEmptySubsequences: true)
        guard comps.count == 2 else {
            throw HTTPParser.Error.invalidVersion }
        let version = comps[1].split(separator: .period, maxSplits: 1, omittingEmptySubsequences: true)
        guard 1...2 ~= version.count, let major = version.first?.decimalInt else {
            throw HTTPParser.Error.invalidVersion }

        let minor: Int
        if version.count == 2 {
            guard let m = version[1].decimalInt else {
                throw HTTPParser.Error.invalidVersion }
            minor = m
        } else {
            minor = 0
        }

        self = Version(major: major, minor: minor)
    }
}
