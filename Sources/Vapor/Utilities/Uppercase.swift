// https://stackoverflow.com/questions/39592563/split-string-in-swift-by-their-capital-letters

extension Character {
    internal var isUppercase: Bool {
        return String(self) == String(self).uppercased()
    }
}

extension Sequence {
    internal func splitBefore(
        whereSeparator isSeparator: (Iterator.Element) throws -> Bool
    ) rethrows -> [AnySequence<Iterator.Element>] {
        var result: [AnySequence<Iterator.Element>] = []
        var subSequence: [Iterator.Element] = []

        var iterator = self.makeIterator()
        while let element = iterator.next() {
            if try isSeparator(element) {
                if !subSequence.isEmpty {
                    result.append(AnySequence(subSequence))
                }
                subSequence = [element]
            }
            else {
                subSequence.append(element)
            }
        }
        result.append(AnySequence(subSequence))
        return result
    }
}

extension String {
    internal func splitUppercaseCharacters() -> [String] {
        return characters
            .splitBefore(whereSeparator: { $0.isUppercase })
            .map({ String($0) })
    }
}
