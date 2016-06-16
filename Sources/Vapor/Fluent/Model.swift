public protocol Model: FluentModel, JSONRepresentable, StringInitializable { }

extension Model {
    public init?(from string: String) throws {
        if let model = try Self.find(string) {
            self = model
        } else {
            return nil
        }
    }

    public func makeJson() -> JSON {
        var json: [String: JSON] = [:]

        for (key, value) in serialize() {
            let jsonValue: JSON

            if let value = value {
                switch value.structuredData {
                case .int(let int):
                    jsonValue = .number(JSON.Number.integer(int))
                case .string(let string):
                    jsonValue = .string(string)
                default:
                    jsonValue = .null
                }
            } else {
                jsonValue = .null
            }

            json[key] = jsonValue
        }

        return JSON(json)
    }
}
