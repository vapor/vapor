extension HTTPHeaders: Codable {
    public init(from decoder: Decoder) throws {
        let dictionary = try decoder.singleValueContainer().decode([String: String].self)
        self.init()
        for (name, value) in dictionary {
            self.add(name: name, value: value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var dictionary: [String: String] = [:]
        for (name, value) in self {
            dictionary[name] = value
        }
        var container = encoder.singleValueContainer()
        try container.encode(dictionary)
    }
}
