
extension HTTPMessage: CustomStringConvertible {
    public var description: String {
        var d = ""
        d += "REQUEST:\n"
        d += "\t\(startLine)\n"
        d += "\tHEADERS:"
        let headersstring = headers.map { field, val in "\(field): \(val)" } .joined(separator: "\n\t\t")
        d += "\t\t\(headersstring)"
        d += "\tBody:\n\t\t\(body.bytes?.string ?? "n/a")"
        return d
    }
}

