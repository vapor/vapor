extension Data {
    func split(separator: Data, excludingFirst: Bool = false, excludingLast: Bool = false, maxSplits: Int? = nil) -> [Data] {
        // "\r\n\r\n\r\n".split(separator: "\r\n\r\n") would break without this because it occurs twice in the same place
        var parts = [Data]()
        let array = self.enumerated().filter { (index, element) in
            // If this first element matches and there are enough bytes left
            let leftMatch = element == separator.first
            let rightIndex = index + separator.count - 1
            // Take the last byte of where the end of the separator would be and check it
            let rightMatch: Bool
            if rightIndex < self.bytes.count {
                rightMatch = self[rightIndex] == separator.bytes.last
            } else {
                rightMatch = false
            }
            if leftMatch && rightMatch {
                // Check if this range matches (put separately for efficiency)
                return Data(self[index..<(index+separator.count)]) == separator
            } else {
                return false
            }
        }
        let separatorLength = separator.count
        var ranges = array.map { (index, element) -> (from: Int, to: Int) in
            return (index, index + separatorLength)
        }
        if let max = maxSplits {
            if ranges.count > max {
                ranges = ranges.prefix(upTo: max).array
            }
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

func +=(lhs: inout Data, rhs: Data) {
    lhs.bytes += rhs.bytes
}


func +=(lhs: inout Data, rhs: Byte) {
    lhs.bytes.append(rhs)
}

