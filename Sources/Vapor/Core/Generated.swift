extension Application {

	public func get(p0: String, handler: (Request) throws -> ResponseConvertible) {
		self.add(.Get, path: "/\(p0)") { request in
			return try handler(request)
		}
	}

	public func get<T: StringInitializable>(w0: T.Type, handler: (Request, T) throws -> ResponseConvertible) {
		self.add(.Get, path: "/:w0") { request in
			guard let vw0 = request.parameters["w0"] else {
				throw Abort.BadRequest
			}

			let ew0 = try T(from: vw0)

			guard let cw0 = ew0 else {
				throw Abort.BadRequest
			}

			return try handler(request, cw0)
		}
	}

	public func get(p0: String, _ p1: String, handler: (Request) throws -> ResponseConvertible) {
		self.add(.Get, path: "/\(p0)/\(p1)") { request in
			return try handler(request)
		}
	}

	public func get<T: StringInitializable>(p0: String, _ w0: T.Type, handler: (Request, T) throws -> ResponseConvertible) {
		self.add(.Get, path: "/\(p0)/:w0") { request in
			guard let vw0 = request.parameters["w0"] else {
				throw Abort.BadRequest
			}

			let ew0 = try T(from: vw0)

			guard let cw0 = ew0 else {
				throw Abort.BadRequest
			}

			return try handler(request, cw0)
		}
	}

	public func get<T: StringInitializable>(w0: T.Type, _ p0: String, handler: (Request, T) throws -> ResponseConvertible) {
		self.add(.Get, path: "/:w0/\(p0)") { request in
			guard let vw0 = request.parameters["w0"] else {
				throw Abort.BadRequest
			}

			let ew0 = try T(from: vw0)

			guard let cw0 = ew0 else {
				throw Abort.BadRequest
			}

			return try handler(request, cw0)
		}
	}

	public func get<T: StringInitializable, U: StringInitializable>(w0: T.Type, _ w1: U.Type, handler: (Request, T, U) throws -> ResponseConvertible) {
		self.add(.Get, path: "/:w0/:w1") { request in
			guard let vw0 = request.parameters["w0"] else {
				throw Abort.BadRequest
			}
			guard let vw1 = request.parameters["w1"] else {
				throw Abort.BadRequest
			}

			let ew0 = try T(from: vw0)
			let ew1 = try U(from: vw1)

			guard let cw0 = ew0 else {
				throw Abort.BadRequest
			}
			guard let cw1 = ew1 else {
				throw Abort.BadRequest
			}

			return try handler(request, cw0, cw1)
		}
	}

	public func post(p0: String, handler: (Request) throws -> ResponseConvertible) {
		self.add(.Post, path: "/\(p0)") { request in
			return try handler(request)
		}
	}

	public func post<T: StringInitializable>(w0: T.Type, handler: (Request, T) throws -> ResponseConvertible) {
		self.add(.Post, path: "/:w0") { request in
			guard let vw0 = request.parameters["w0"] else {
				throw Abort.BadRequest
			}

			let ew0 = try T(from: vw0)

			guard let cw0 = ew0 else {
				throw Abort.BadRequest
			}

			return try handler(request, cw0)
		}
	}

	public func post(p0: String, _ p1: String, handler: (Request) throws -> ResponseConvertible) {
		self.add(.Post, path: "/\(p0)/\(p1)") { request in
			return try handler(request)
		}
	}

	public func post<T: StringInitializable>(p0: String, _ w0: T.Type, handler: (Request, T) throws -> ResponseConvertible) {
		self.add(.Post, path: "/\(p0)/:w0") { request in
			guard let vw0 = request.parameters["w0"] else {
				throw Abort.BadRequest
			}

			let ew0 = try T(from: vw0)

			guard let cw0 = ew0 else {
				throw Abort.BadRequest
			}

			return try handler(request, cw0)
		}
	}

	public func post<T: StringInitializable>(w0: T.Type, _ p0: String, handler: (Request, T) throws -> ResponseConvertible) {
		self.add(.Post, path: "/:w0/\(p0)") { request in
			guard let vw0 = request.parameters["w0"] else {
				throw Abort.BadRequest
			}

			let ew0 = try T(from: vw0)

			guard let cw0 = ew0 else {
				throw Abort.BadRequest
			}

			return try handler(request, cw0)
		}
	}

	public func post<T: StringInitializable, U: StringInitializable>(w0: T.Type, _ w1: U.Type, handler: (Request, T, U) throws -> ResponseConvertible) {
		self.add(.Post, path: "/:w0/:w1") { request in
			guard let vw0 = request.parameters["w0"] else {
				throw Abort.BadRequest
			}
			guard let vw1 = request.parameters["w1"] else {
				throw Abort.BadRequest
			}

			let ew0 = try T(from: vw0)
			let ew1 = try U(from: vw1)

			guard let cw0 = ew0 else {
				throw Abort.BadRequest
			}
			guard let cw1 = ew1 else {
				throw Abort.BadRequest
			}

			return try handler(request, cw0, cw1)
		}
	}

}