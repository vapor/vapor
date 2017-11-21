public struct Comment: Encodable {
    public let lines: [String]
    public let attributes: [String: String]

    public init(lines: [String]) {
        self.lines = lines
        self.attributes = Comment.parseAttributes(fromLines: lines)
    }

    private static func parseAttributes(fromLines lines: [String]) -> [String: String] {
        var attributes: [String: String] = [:]

        for line in lines {
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("- ") {
                let content = line.dropFirst(2)

                let array = content.split(separator: ":", maxSplits: 1)
                guard array.count == 2 else {
                    continue
                }

                let key = String(array[0]).trimmingCharacters(in: .whitespaces)
                let value = String(array[1]).trimmingCharacters(in: .whitespaces)

                attributes[key] = value
            }
        }

        return attributes
    }
}
