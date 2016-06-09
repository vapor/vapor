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
        var f = ""
        f << "\(signature.description) {"
        f << body.description
        f << "}"
        return f
    }
}
