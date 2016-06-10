extension Equatable {
    func equals(any: Self...) -> Bool {
        return any.contains(self)
    }
    func equals(any: [Self]) -> Bool {
        return any.contains(self)
    }
}
