extension String {
    /// Returns a new string with the camel-case-based words of this string
    /// split by the specified separator.
    ///
    /// Examples:
    ///
    ///     "myProperty".convertedToSnakeCase()
    ///     // my_property
    ///     "myURLProperty".convertedToSnakeCase()
    ///     // my_url_property
    ///     "myURLProperty".convertedToSnakeCase(separator: "-")
    ///     // my-url-property
    func convertedToSnakeCase(separator: Character = "_") -> String {
        guard !isEmpty else { return "" }
        var result = ""
        // Whether we should append a separator when we see a uppercase character.
        var separateOnUppercase = true
        for index in indices {
            let nextIndex = self.index(after: index)
            let character = self[index]
            if character.isUppercase {
                if separateOnUppercase && !result.isEmpty {
                    // Append the separator.
                    result += "\(separator)"
                }
                // If the next character is uppercase and the next-next character is lowercase, like "L" in "URLSession", we should separate words.
                separateOnUppercase = nextIndex < endIndex && self[nextIndex].isUppercase && self.index(after: nextIndex) < endIndex && self[self.index(after: nextIndex)].isLowercase
            } else {
                // If the character is `separator`, we do not want to append another separator when we see the next uppercase character.
                separateOnUppercase = character != separator
            }
            // Append the lowercased character.
            result += character.lowercased()
        }
        return result
    }
}
