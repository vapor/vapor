extension Json {

	/** Recursively merges two Json objects */
	mutating func merge(with: Json) {
		switch with {
			case .ObjectValue(let object):
				guard case let .ObjectValue(object2) = self else {
					self = with
					return
				}

				var merged = object2

				for (key, value) in object {
					if let original = merged[key] {
						var newValue = original
						newValue.merge(value)
						merged[key] = newValue
					} else {
						merged[key] = value
					}
				}

				self = .ObjectValue(merged)
			case .ArrayValue(let array):
				guard case let .ArrayValue(array2) = self else {
					self = with
					return
				}

				self = .ArrayValue(array + array2)
			default:
				self = with
		}

	}

}
