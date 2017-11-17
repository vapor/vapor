extension Console {
    /// Choose an item from the supplied array.
    /// Each item will be converted to a string via CustomStringConvertible.
    public func choose<T>(title: String, from array: [T]) throws -> T
        where T: CustomStringConvertible
    {
        return try choose(title: title, from: array, display: { $0.description })
    }

    /// Choose an item from the supplied array, using the closure to
    /// convert each item to a string.
    public func choose<T>(title: String, from array: [T], display: (T) -> String) throws -> T {
        try info(title)
        try array.enumerated().forEach { idx, item in
            let offset = idx + 1
            try info("\(offset): ", newLine: false)
            let description = display(item)
            try print(description)
        }

        var res: T?
        while res == nil {
            try output("> ", style: .plain, newLine: false)
            let raw = try input()
            guard let idx = Int(raw), (1...array.count).contains(idx) else {
                // .count is implicitly offset, no need to adjust
                try clear(.line)
                continue
            }

            // undo previous offset back to 0 indexing
            let offset = idx - 1
            res = array[offset]
        }

        // + 1 for > input line
        // + 1 for title line
        let lines = array.count + 2
        for _ in 1...lines {
            try clear(.line)
        }

        return res!
    }
}
