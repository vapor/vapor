extension Validatable {
    @available(*, deprecated, renamed: "validate(content:)")
    public static func validate(_ request: Request) throws {
        try self.validations().validate(request: request).assert()
    }
}
