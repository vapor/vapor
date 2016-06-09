struct Function {
    var signature: Signature

    init(variant: Variant, method: Method, parameters: [Parameter]) {
        signature = Signature(variant: variant, method: method, parameters: parameters)
    }
}

extension Function: CustomStringConvertible {
    var description: String {
        return signature.description
    }
}
