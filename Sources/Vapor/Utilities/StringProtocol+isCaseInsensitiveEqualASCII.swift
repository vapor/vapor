extension StringProtocol {
    func isCaseInsensitiveEqualASCII(to other: some StringProtocol) -> Bool {
        let a = self.utf8, b = other.utf8
        guard a.count == b.count else { return false }
        for (x, y) in zip(a, b) {
            let fx = (0x41...0x5A).contains(x) ? x &+ 0x20 : x  // fold A–Z only
            let fy = (0x41...0x5A).contains(y) ? y &+ 0x20 : y
            if fx != fy { return false }
        }
        return true
    }
}
