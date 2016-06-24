/**
    Providers allow external projects to be easily
    integrated into a Vapor application.

    Simply append a dependencies provider to the Application's
    `providers` array.

    The Provider should take care of setting up any
    necessary configurations on itself and the Application.
*/
public protocol Provider {
    /**
        Providers should use this function to do any setup or configuration necessary to provide

        - parameter application: the application to which the provider will be providing
    */
    func boot(with application: Application)

    /**
        An optional `ServerDriver` Type to provide
        to the application. Has a default 
        implementation of `nil`.
     
        `ServerDriver`s are passed as types since
        they are not initialized until the 
        application starts.
    */
    var server: Server.Type? { get }

    /**
        An optional `RouterDriver` to provide 
        to the application. Has a default
        implementation of `nil`.
    */
    var router: Router? { get }

    /**
        An optional `Session` to provide
        to the application. Has a default
        implementation of `nil`.
    */
    var sessions: Sessions? { get }


    /**
        An optional `HashDriver` to provide
        to the application. Has a default
        implementation of `nil`.
     */
    var hash: Hash? { get }

    /**
        An optional `ConsoleDriver` to provide
        to the application. Has a default
        implementation of `nil`.
    */
    var console: Console? { get }


    /**
         An optional `HTTPClient` add-on used to make
         outgoing web request operations
     */
    var client: Client.Type? { get }
}

extension Provider {
    public var server: Server.Type? {
        return nil
    }

    public var router: Router? {
        return nil
    }

    public var sessions: Sessions? {
        return nil
    }

    public var hash: Hash? {
        return nil
    }

    public var console: Console? {
        return nil
    }

    public var client: Client.Type? {
        return nil
    }
}
