import S4

/**
    Swift Servers that conform to this protocol
    can be used to power any Vapor application.
*/
public protocol ServerDriver: S4.Server {
}

/**
    The Application class conforms to `ServerDriverDelegate`
    and will be set as any ServerDriver's delegate when the
    application starts.
*/
public protocol ServerDriverDelegate: S4.Responder {
    
}