import Engine
import Console

/**
    Providers allow external projects to be easily
    integrated into a Vapor droplet.

    Simply append a dependencies provider to the Droplet's
    `providers` array.

    The Provider should take care of setting up any
    necessary configurations on itself and the Droplet.
*/
public protocol Provider {
    /**
        Providers should use this function to do any setup or configuration necessary to provide

        - parameter droplet: the droplet to which the provider will be providing
    */
    func boot(with droplet: Droplet)

    /**
        An optional `ServerDriver` Type to provide
        to the droplet. Has a default 
        implementation of `nil`.
     
        `ServerDriver`s are passed as types since
        they are not initialized until the 
        droplet starts.
    */
    var server: Server.Type? { get }

    /**
        An optional `RouterDriver` to provide 
        to the droplet. Has a default
        implementation of `nil`.
    */
    var router: Router? { get }

    /**
        An optional `Session` to provide
        to the droplet. Has a default
        implementation of `nil`.
    */
    var sessions: Sessions? { get }


    /**
        An optional `HashDriver` to provide
        to the droplet. Has a default
        implementation of `nil`.
     */
    var hash: Hash? { get }

    /**
        An optional `ConsoleDriver` to provide
        to the droplet. Has a default
        implementation of `nil`.
    */
    var console: ConsoleProtocol? { get }


    /**
         An optional `HTTPClient` add-on used to make
         outgoing web request operations
     */
    var client: Client.Type? { get }

    var database: DatabaseDriver? { get }
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

    public var console: ConsoleProtocol? {
        return nil
    }

    public var client: Client.Type? {
        return nil
    }

    public var database: DatabaseDriver? {
        return nil
    }
}
