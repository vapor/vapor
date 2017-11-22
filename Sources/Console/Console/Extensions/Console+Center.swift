extension OutputConsole {
    public func center(_ string: String, paddingCharacter: Character = " ") -> String {
        // Split the string into lines
        let lines = string.split(separator: Character("\n")).map(String.init)
        return center(lines).joined(separator: "\n")
    }

    public func center(_ lines: [String], paddingCharacter: Character = " ") -> [String] {
        var lines = lines

        // Make sure there's more than one line
        guard lines.count > 0 else {
            return []
        }

        // Find the longest line
        var longestLine = 0
        for line in lines {
            if line.count > longestLine {
                longestLine = line.count
            }
        }

        // Calculate the padding and make sure it's greater than or equal to 0
        let padding = max(0, (size.width - longestLine) / 2)

        // Apply the padding to each line
        for i in 0..<lines.count {
            for _ in 0..<padding {
                lines[i].insert(paddingCharacter, at: lines[i].startIndex)
            }
        }

        return lines
    }
}
