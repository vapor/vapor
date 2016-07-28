public enum TypeSafeRoutingError: Error {
	case missingParameter
	case invalidParameterType(StringInitializable.Type)
 }
