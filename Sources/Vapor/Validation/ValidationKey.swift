public typealias ValidationKey = BasicCodingKey

/// Old names
extension ValidationKey {
    @available(*, deprecated, renamed: "index(_:)")
    public static func integer(_ i: Int) -> Self { .index(i) }
    
    @available(*, deprecated, renamed: "key(_:)")
    public static func string(_ s: String) -> Self { .key(s) }
}
