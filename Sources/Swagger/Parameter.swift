public final class Parameter: Encodable {
    public enum In: String, Encodable {
        case query, header, path, cookie
        
        var acceptedStyles: [Style] {
            switch self {
            case .query:
                return [.form, .spaceDelimited, .pipeDelimited, .deepObject]
            case .header:
                return [.simple]
            case .path:
                return [.matrix, .label, .simple]
            case .cookie:
                return [.form]
            }
        }
    }
    
    public var name: String
    public var `in`: In
    public var description: String?
    public private(set) var required: Bool?
    public var deprecated: Bool = false
    public var allowEmptyValue: Bool?
    public private(set) var style: Style?
    public var explode: Bool?
    public var allowReserved: Bool?
    public var schema: PossibleReference<Schema>?
    public var examples = [String: PossibleReference<Example>]()
    
    public init(named name: String, in: In) {
        self.name = name
        self.in = `in`
    }
    
    @discardableResult
    public func settingRequired(to required: Bool) throws -> Parameter {
        if !required && self.in == .path {
            throw Error.pathIsRequired
        }
        
        self.required = required
        
        return self
    }
    
    @discardableResult
    public func settingStyle(to style: Style) throws -> Parameter {
        guard self.in.acceptedStyles.contains(style) else {
            throw Error.unacceptableStyle(in: self.in)
        }
        
        self.style = style
        return self
    }
    
    public enum Style: String, Encodable {
        case matrix, label, form, simple, spaceDelimited, pipeDelimited, deepObject
    }
}
