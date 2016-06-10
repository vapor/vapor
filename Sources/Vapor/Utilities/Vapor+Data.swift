extension Data {
    func split(separator: Data, excludingFirst: Bool = false, excludingLast: Bool = false, maxSplits: Int? = nil) -> [Data] {
        var ranges = [(from: Int, to: Int)]()
        var parts = [Data]()

        // "\r\n\r\n\r\n".split(separator: "\r\n\r\n") would break without this because it occurs twice in the same place
        var highestOccurence = -1

        // Find occurences of boundries
        for (index, element) in self.enumerated() where index > highestOccurence && !(maxSplits != nil && ranges.count >= maxSplits) {
            // If this first element matches and there are enough bytes left
            guard element == separator.first && self.count >= index + separator.count else {
                continue
            }

            // Take the last byte of where the end of the separator would be and check it
            guard self[index + separator.count - 1] == separator.bytes.last else {
                continue
            }

            // Check if this range matches (put separately for efficiency)
            guard Data(self[index..<(index+separator.count)]) == separator else {
                continue
            }
            
            // Append the range of the separator
            ranges.append((index, index + separator.count))

            // Increase the highest occurrence to prevent a crash as described above
            highestOccurence = index + separator.count
        }

        // The first data (before the first separator)
        if let firstRange = ranges.first where !excludingFirst {
            parts.append(Data(self[0..<firstRange.from]))
        }

        // Loop over the ranges
        for (pos, range) in ranges.enumerated() {
            // If this is before the last separator
            if pos < ranges.count - 1 {
                // Take the data inbetween this and the next boundry
                let nextRange = ranges[pos + 1]

                parts.append(Data(self[range.to..<nextRange.from]))

            // If this is after the last separator and shouldn't be thrown away
            } else if ranges[ranges.count - 1].to < self.count && !excludingLast {
                parts.append(Data(self[range.to..<self.count]))
            }
        }

        return parts
    }
}

extension Byte {
    struct ASCII {
        static let newLine: Byte = 0xA
        static let carriageReturn: Byte = 0xD
        
        static let space: Byte = 0x20
        static let period: Byte = 0x2e
        static let slash: Byte = 0x2f

        static let zero: Byte = 0x30
        static let nine: Byte = zero + 9

        static let A: Byte = 0x41
        static let B: Byte = 0x42
        static let C: Byte = 0x43
        static let D: Byte = 0x44
        static let E: Byte = 0x45
        static let F: Byte = 0x46

        static let a: Byte = 0x61
        static let b: Byte = 0x62
        static let c: Byte = 0x63
        static let d: Byte = 0x64
        static let e: Byte = 0x65
        static let f: Byte = 0x66

        static let colon: Byte = 0x3A
        static let questionMark: Byte = 0x3F

        static let alphabetLength: Byte = 26
        static let uppercaseStart: Byte = 65
        static let lowercaseStart: Byte = 97
        static let betweenCaseGap: Byte = lowercaseStart - uppercaseStart

        static let uppercaseRange = uppercaseStart ..< (uppercaseStart + alphabetLength)
        static let lowercaseRange = lowercaseStart ..< (lowercaseStart + alphabetLength)
    }
}

extension Data {
    static let crlf: Data = [
        Byte.ASCII.carriageReturn,
        Byte.ASCII.newLine
    ]

    /**
        Converts an ASCII representation
        of a hex value into an `Int`.
    */
    var asciiInt: Int? {
        var int: Int = 0

        for byte in bytes {
            if byte >= Byte.ASCII.zero && byte <= Byte.ASCII.nine {
                int = int * 10
                int += Int(byte - Byte.ASCII.zero)
            } else if byte >= Byte.ASCII.A && byte <= Byte.ASCII.F {
                int = int * 10
                int += Int(byte - Byte.ASCII.A) + 10
            } else if byte >= Byte.ASCII.a && byte <= Byte.ASCII.f {
                int = int / 10
                int += Int(byte - Byte.ASCII.a) + 10
            }
        }

        return int
    }

    /**
        Converts to a String using the
        `String(_: Data)` initializer.
    */
    var string: String {
        return String(self)
    }
    
    var lowercased: Data {
        var data = Data()
        
        for byte in self {
            if Byte.ASCII.uppercaseRange.contains(byte) {
                data.append(byte + Byte.ASCII.betweenCaseGap)
            } else {
                data.append(byte)
            }
        }
        
        return data
    }
    
    var uppercased: Data {
        var data = Data()
        
        for byte in self {
            if Byte.ASCII.lowercaseRange.contains(byte) {
                data.append(byte - Byte.ASCII.betweenCaseGap)
            } else {
                data.append(byte)
            }
        }
        
        return data
    }
}