struct Function {
    var signature: Signature
    var body: Body

    init(variant: Variant, method: Method, parameters: [Parameter]) {
        signature = Signature(variant: variant, method: method, parameters: parameters)
        body = Body(signature: signature)
    }
}

extension Function: CustomStringConvertible {
    var description: String {
        return [
            "\(signature.description) {",
            body.description.indented,
            "}"
        ].joined(separator: "\n")
    }
}
