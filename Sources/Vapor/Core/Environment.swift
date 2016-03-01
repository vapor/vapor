public enum Environment: Equatable {
	case Production
	case Test
	case Development
	case Custom(String)

	static func fromString(string: String) -> Environment {
		let string = string.lowercaseString

		switch string {
		case "production": return .Production
		case "test": return .Test
		case "development": return .Development
		default: return .Custom(string)
		}
	}
}

extension Environment: CustomStringConvertible {

	public var description: String {
		switch self {
		case Production: return "production"
		case Test: return "test"
		case Development: return "development"
		case Custom(let string): return string
		}
	}

}

public func ==(lhs: Environment, rhs: Environment) -> Bool {
	return lhs.description == rhs.description
}
