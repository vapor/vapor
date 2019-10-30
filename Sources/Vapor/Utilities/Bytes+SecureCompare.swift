extension Collection where Element: Equatable {
    /// Performs a full-comparison of all elements in two collections. If the two collections have
    /// a different number of elements, the function will compare all elements in the smaller collection
    /// first and then return false.
    ///
    ///     let a, b: Data
    ///     let res = a.secureCompare(to: b)
    ///
    /// This method does not make use of any early exit functionality, making it harder to perform timing
    /// attacks on the comparison logic. Use this method if when comparing secure data like hashes.
    ///
    /// - parameters:
    ///     - other: Collection to compare to.
    /// - returns: `true` if the collections are equal.
    public func secureCompare<C>(to other: C) -> Bool where C: Collection, C.Element == Element {
        let chk = self
        let sig = other

        // byte-by-byte comparison to avoid timing attacks
        var match = true
        for i in 0..<Swift.min(chk.count, sig.count) {
            if chk[chk.index(chk.startIndex, offsetBy: i)] != sig[sig.index(sig.startIndex, offsetBy: i)] {
                match = false
            }
        }

        // finally, if the counts match then we can accept the result
        if chk.count == sig.count {
            return match
        } else {
            return false
        }
    }
}
