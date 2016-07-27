extension Collection where Iterator.Element == Byte, IndexDistance == Int, Index == Int, SubSequence.Iterator.Element == Byte {
    func split(separator: Bytes, excludingFirst: Bool = false, excludingLast: Bool = false, maxSplits: Int? = nil) -> [Bytes] {
        // "\r\n\r\n\r\n".split(separator: "\r\n\r\n") would break without this because it occurs twice in the same place
        var parts: [[Iterator.Element]] = []
        let array = self.enumerated().filter { (index, element) in
            // If this first element matches and there are enough bytes left
            let leftMatch = element == separator.first
            let rightIndex = index + separator.count - 1
            // Take the last byte of where the end of the separator would be and check it
            let rightMatch: Bool
            if rightIndex < self.count {
                rightMatch = self[rightIndex] == separator.last
            } else {
                rightMatch = false
            }
            if leftMatch && rightMatch {
                // Check if this range matches (put separately for efficiency)
                return self[index..<(index+separator.count)].array == separator
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
        if let firstRange = ranges.first, !excludingFirst {
            parts.append(self.prefix(upTo: firstRange.from).array)
        }

        // Loop over the ranges
        for (pos, range) in ranges.enumerated() {
            // If this is before the last separator
            if pos < ranges.count - 1 {
                // Take the data inbetween this and the next boundry
                let nextRange = ranges[pos + 1]

                parts.append(self[range.to..<nextRange.from].array)

            // If this is after the last separator and shouldn't be thrown away
            } else if ranges[ranges.count - 1].to < self.count && !excludingLast {
                parts.append(self[range.to..<self.count].array)
            }
        }

        return parts
    }
}

func +=(lhs: inout Bytes, rhs: Byte) {
    lhs.append(rhs)
}

