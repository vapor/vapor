public typealias BytesSlice = ArraySlice<Byte>

func ~=(pattern: Bytes, value: BytesSlice) -> Bool {
    return BytesSlice(pattern) == value
}

func ~=(pattern: BytesSlice, value: BytesSlice) -> Bool {
    return pattern == value
}

extension Array where Element: Hashable {
    /**
        This function is intended to be as performant as possible, which is part of the reason
        why some of the underlying logic may seem a bit more tedious than is necessary
    */
    func trimmed(_ elements: [Element]) -> SubSequence {
        guard !isEmpty else { return [] }

        let lastIdx = self.count - 1
        var leadingIterator = self.indices.makeIterator()
        var trailingIterator = leadingIterator

        var leading = 0
        var trailing = lastIdx
        while let next = leadingIterator.next() where elements.contains(self[next]) {
            leading += 1
        }
        while let next = trailingIterator.next() where elements.contains(self[lastIdx - next]) {
            trailing -= 1
        }

        return self[leading...trailing]
    }
}


extension ArraySlice where Element: Hashable {
    /**
        This function is intended to be as performant as possible, which is part of the reason
        why some of the underlying logic may seem a bit more tedious than is necessary
    */
    func trimmed(_ elements: [Element]) -> SubSequence {
        guard !isEmpty else { return [] }

        let firstIdx = startIndex
        let lastIdx = endIndex - 1// self.count - 1

        var leadingIterator = self.indices.makeIterator()
        var trailingIterator = leadingIterator

        var leading = firstIdx
        var trailing = lastIdx
        while let next = leadingIterator.next() where elements.contains(self[next]) {
            leading += 1
        }
        while let next = trailingIterator.next() where elements.contains(self[lastIdx - next]) {
            trailing -= 1
        }
        
        return self[leading...trailing]
    }
}
