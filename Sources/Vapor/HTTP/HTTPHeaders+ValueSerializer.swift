extension HTTPHeaders {
    struct ValueSerializer {
        let value: String?
        let parameters: [(String, String)]

        init(value: String?, parameters: [(String, String)]) {
            self.value = value
            self.parameters = parameters
        }

        func serialize() -> String {
            var header = ""

            if let value = self.value {
                header += value
            }

            for (key, value) in self.parameters {
                if !header.isEmpty {
                    header += "; "
                }
                header += "\(key)=\(value)"
            }

            return header
        }
    }
}
