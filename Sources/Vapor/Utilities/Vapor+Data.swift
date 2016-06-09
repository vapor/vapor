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

extension Data {
    static let uppercaseRange = 65...90
    static let lowercaseRange = 97...122
    
    func lowercased() -> Data {
        var data = Data()
        
        for byte in self {
            if Data.uppercaseRange.contains(Int(byte)) {
                data.append(byte + 32)
            } else {
                data.append(byte)
            }
        }
        
        return data
    }
    
    func uppercased() -> Data {
        var data = Data()
        
        for byte in self {
            if Data.lowercaseRange.contains(Int(byte)) {
                data.append(byte - 32)
            } else {
                data.append(byte)
            }
        }
        
        return data
    }
}