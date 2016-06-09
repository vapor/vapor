extension Array {
    func split(by subSize: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: subSize).map { startIndex in
            let next = startIndex.advanced(by: subSize)
            let end = next <= endIndex ? next : endIndex
            return Array(self[startIndex ..< end])
        }
    }
}
