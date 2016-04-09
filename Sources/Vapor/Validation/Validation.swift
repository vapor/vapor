@_exported import Validated

// TODO: This is temporary to speed up dev, use real errors before :ship:
extension String: ErrorProtocol {}

extension Request.Content {
    public func validated<ValidatorType: Validator>(key: String) throws -> Validated<ValidatorType> {
        guard let val = self[key] else {
            throw "no value"
        }

        // It's going to be Node so 'String' or 'Json'. We need to constrain `Wrapped` type to `Node` convertible
        // Propose to Tanner that query is also Json and => `[String : .string(value)]`. This will be easier for users to map
        // Mapping should be fuzzy.
        guard let input = val as? ValidatorType.WrappedType else {
            throw "not correct input type"
        }

        return try Validated<ValidatorType>(input)
    }
}
