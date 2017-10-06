import Foundation

extension Array {
    public var random: Element? {
        guard count > 0 else {
            return nil
        }
        
        let random = OSRandom()
            .bytes(count: MemoryLayout<UInt>.size)
            .cast(to: UInt.self)
        
        let index = random % UInt(count)
        return self[Int(index)]
    }
}
