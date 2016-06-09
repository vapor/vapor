infix operator <<< { }

func <<<(lhs: inout String, rhs: String) {
    return lhs.append(rhs)
}

func <<(lhs: inout String, rhs: String) {
    return lhs.append(rhs + "\n")
}
