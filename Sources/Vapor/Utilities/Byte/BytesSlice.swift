public typealias BytesSlice = ArraySlice<Byte>

func ~=(pattern: Bytes, value: BytesSlice) -> Bool {
    return BytesSlice(pattern) == value
}

func ~=(pattern: BytesSlice, value: BytesSlice) -> Bool {
    return pattern == value
}
