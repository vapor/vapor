//
//extension HTTPMessage: CustomStringConvertible {
//    public var description: String {
//        var d: [String] = []
//
//        d += "\(self.dynamicType)"
//        d += "- " + startLine
//        d += "- Headers:"
//        d += headers.map { field, val in "\t\(field): \(val)" } .joined(separator: "\n")
//        d += "- Body:"
//        d += "\t\(body.bytes?.string ?? "n/a")"
//
//        return d.joined(separator: "\n")
//    }
//}
//
