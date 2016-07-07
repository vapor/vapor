// TODO: Remove when HTTP Replaced
extension String {
    func finish(_ end: String) -> String {
        guard !self.hasSuffix(end) else {
            return self
        }

        return self + end
    }
}
