extension CORSMiddleware.AllowOriginSetting {
    @available(*, deprecated, renamed: "any")
    public static func whitelist(_ origins: [String]) -> Self {
        .any(origins)
    }
}
