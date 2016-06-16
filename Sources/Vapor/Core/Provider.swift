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
    var server: ServerDriver.Type? { get }

    /**
        An optional `RouterDriver` to provide 
        to the application. Has a default
        implementation of `nil`.
    */
    var router: RouterDriver? { get }

    /**
        An optional `SessionDriver` to provide
        to the application. Has a default
        implementation of `nil`.
    */
    var session: SessionDriver? { get }


    /**
        An optional `HashDriver` to provide
        to the application. Has a default
        implementation of `nil`.
     */
    var hash: HashDriver? { get }

    /**
        An optional `ConsoleDriver` to provide
        to the application. Has a default
        implementation of `nil`.
    */
    var console: ConsoleDriver? { get }

    /**
        An optional `Database` to provide
        to the application. Has a default
        implementation of `nil`.
    */
    var database: DatabaseDriver? { get }
}

extension Provider {
    public var server: ServerDriver.Type? {
        return nil
    }

    public var router: RouterDriver? {
        return nil
    }

    public var session: SessionDriver? {
        return nil
    }

    public var hash: HashDriver? {
        return nil
    }

    public var console: ConsoleDriver? {
        return nil
    }

    public var database: DatabaseDriver? {
        return nil
    }
}
