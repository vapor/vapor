infix operator <<< { }

func <<<(lhs: inout String, rhs: String) {
    return lhs.append(rhs)
}

func <<(lhs: inout String, rhs: String) {
    return lhs.append(rhs + "\n")
}

extension String {
    var indented: String {
        let split = self.characters.split(separator: "\n")
        return split.map { "    " + String($0) }.joined(separator: "\n")
    }
}
