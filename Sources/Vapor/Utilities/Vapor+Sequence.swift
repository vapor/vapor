extension Sequence {
    var array: [Iterator.Element] {
        return Array(self)
    }
}
