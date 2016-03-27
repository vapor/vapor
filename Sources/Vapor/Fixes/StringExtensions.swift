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
        let signedData = data.map { byte in
            return Int8(byte)
        }
        
        guard let string = String(validatingUTF8: signedData) else {
            return nil
        }
        
        self = string
    }

#if os(Linux)
    func hasPrefix(str: String) -> Bool {
        let strGen = str.characters.makeIterator()
        let selfGen = self.characters.makeIterator()
        let seq = Zip2Sequence(strGen, selfGen)
        for (lhs, rhs) in seq where lhs != rhs {
            return false
        }
        return true
    }
    
    func hasSuffix(str: String) -> Bool {
        let strGen = str.characters.reversed().makeIterator()
        let selfGen = self.characters.reversed().makeIterator()
        let seq = Zip2Sequence(strGen, selfGen)
        for (lhs, rhs) in seq where lhs != rhs {
            return false
        }
        return true
    }

#endif
}