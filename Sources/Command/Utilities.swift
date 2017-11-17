extension Array {
    /// Pops the first element from the array.
    mutating func popFirst() -> Element? {
        guard let pop = first else {
            return nil
        }
        self = Array(dropFirst())
        return pop
    }
}
