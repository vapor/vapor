extension Console {
    public func input(isSecure: Bool = false) throws -> String {
        didOutputLines(count: 1)
        return try action(.input(isSecure: isSecure)) ?? ""
    }
}
