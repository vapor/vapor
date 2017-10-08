extension Packet {
    /// Decodes an HTTP/2 integer
    ///
    /// http://httpwg.org/specs/rfc7541.html#rfc.section.5.1
    func parseInteger(prefix n: Int) throws -> Int {
        guard n >= 1 && n <= n, position < data.count else {
            throw Error(.invalidPrefixSize(n))
        }
        
        let max: UInt8 = numericCast(power(of: 2, to: n) - 1)
        var byte: UInt8 = data[position] & max
        
        position += 1
        
        if byte < max {
            return numericCast(byte)
        }
        
        var integer: Int = numericCast(byte)
        var offset = 0
        
        repeat {
            byte = data[position]
            position += 1
            integer += numericCast(byte & 0b01111111) * power(of: 2, to: offset)
            offset += 7
            // While the significant bit is set
        } while byte & 0b10000000 == 0b10000000
        
        return integer
    }
}

fileprivate func power(of base: Int, to times: Int) -> Int {
    var amount = base
    
    if times == 0 {
        return 1
    }
    
    for _ in 0..<times - 1 {
        amount = amount &* base
    }
    
    return amount
}
