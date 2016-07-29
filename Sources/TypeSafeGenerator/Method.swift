enum Method {
    case get, post, put, patch, delete, options
}

extension Method {
    var uppercase: String {
        return "\(self)".uppercased()
    }
    var lowercase: String {
        return "\(self)".lowercased()
    }
}
