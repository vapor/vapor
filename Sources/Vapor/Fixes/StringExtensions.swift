@_exported import String
import libc

extension String {
    public func finish(ending: String) -> String {
        if hasSuffix(ending) {
            return self
        } else {
            return self + ending
        }
    }

    init?(data: [UInt8]) {
        var signedData = data.map { byte in
            return Int8(byte)
        }
        signedData.append(0)

        guard let string = String(validatingUTF8: signedData) else {
            return nil
        }

        self = string
    }

    func pad(with character: String, to length: Int) -> String {
        var string = self

        while string.characters.count < length {
            string += character
        }

        return string
    }

    func rangeOfString(str: String) -> Range<Index>? {
        return rangeOfString(str, range: self.startIndex..<self.endIndex)
    }

    func rangeOfString(str: String, range: Range<Index>) -> Range<Index>? {
        let target = self[range]
        var index: Index? = nil

        target.withCString { (targetBytes) in
            str.withCString { (strBytes) in
                let p = strstr(targetBytes, strBytes)

                if p != nil {
                    index = target.startIndex.advanced(by: p - UnsafeMutablePointer<Int8>(targetBytes))
                    index = self.startIndex.advanced(by: self.startIndex.distance(to: range.startIndex)).advanced(by: target.startIndex.distance(to: index!))
                }
            }
        }

        guard let startIndex = index else {
            return nil
        }

        return startIndex..<startIndex.advanced(by: str.characters.count)
    }

#if os(Linux)
    func hasPrefix(str: String) -> Bool {
        let strGen = str.characters.makeIterator()
        let selfGen = self.characters.makeIterator()
        let seq = zip(strGen, selfGen)
        for (lhs, rhs) in seq where lhs != rhs {
            return false
        }
        return true
    }

    func hasSuffix(str: String) -> Bool {
        let strGen = str.characters.reversed().makeIterator()
        let selfGen = self.characters.reversed().makeIterator()
        let seq = zip(strGen, selfGen)
        for (lhs, rhs) in seq where lhs != rhs {
            return false
        }
        return true
    }

#endif
}
