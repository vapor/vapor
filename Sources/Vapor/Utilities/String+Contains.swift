extension String {
	func contains(_ other: String) -> Bool {
		return range(of: other) != nil
	}
}
