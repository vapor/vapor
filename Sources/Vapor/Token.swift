import HTTP

public enum Token {
    public typealias Writer = ((Message, String) throws -> ())
    public typealias Reader = ((Message) throws -> (String))
    
    public func cookie(named name: String) -> Reader {
        return { message in
            message.headers[.cookie]
        }
    }
    
    public func cookie(named name: String) -> Writer {
        
    }
}
