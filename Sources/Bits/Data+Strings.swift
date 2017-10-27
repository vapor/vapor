import Foundation

public let asciiCasingOffset = Byte.a - Byte.A

extension Data {
    public func lowercasedASCIIString() -> Data {
        var lowercased = Data(repeating: 0, count: self.count)
        var writeIndex = 0
        
        for i in self.startIndex..<self.endIndex {
            if self[i] >= .A && self[i] <= .Z {
                lowercased[writeIndex] = self[i] &+ asciiCasingOffset
            } else {
                lowercased[writeIndex] = self[i]
            }
            
            writeIndex = writeIndex &+ 1
        }
        
        return lowercased
    }
}
