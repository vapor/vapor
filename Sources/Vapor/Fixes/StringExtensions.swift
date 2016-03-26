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
}