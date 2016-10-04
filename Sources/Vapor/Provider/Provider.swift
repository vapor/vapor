import Core

/**
    Providers allow external projects to be easily
    integrated into a Vapor droplet.

    Simply append a dependencies provider to the Droplet's
    `providers` array.

    The Provider should take care of setting up any
    necessary configurations on itself and the Droplet.
*/
public protocol Provider: ConfigInitializable {
    var provided: Providable { get }

    func boot(_: Droplet)

    /**
        Called after the Droplet has completed
        initialization and all provided items
        have been accepted.
    */
    func afterInit(_: Droplet)

    /**
        Called before the Droplet begins serving
        which is @noreturn.
    */
    func beforeRun(_: Droplet)
}

extension Provider {
    public func boot(_ drop: Droplet) {
        print("[DEPRECATED] Providers should implement the `boot(_: Droplet)` method to register dependencies. The `provided` property will be removed in a future update.")

        if let server = provided.server {
            drop.server = server
        }

        if let hash = provided.hash {
            drop.hash = hash
        }

        if let cipher = provided.cipher {
            drop.cipher = cipher
        }

        if let console = provided.console {
            drop.console = console
        }

        if let log = provided.log {
            drop.log = log
        }

        if let view = provided.view {
            drop.view = view
        }

        if let client = provided.client {
            drop.client = client
        }

        if let database = provided.database {
            drop.database = database
        }

        if let cache = provided.cache {
            drop.cache = cache
        }

        if let middleware = provided.middleware {
            for (name, middleware) in middleware {
                drop.addConfigurable(middleware: middleware, name: name)
            }
        }
    }

    public func afterInit(_ drop: Droplet) {
        //
    }

    public var provided: Providable {
        return Providable()
    }
}

extension Provider {
    public var name: String {
        let type = "\(type(of: self))"
        guard let characters = type.characters.split(separator: " ").first else {
            return "Provider"
        }

        let trimmed = Array(characters).trimmed(["("])

        return String(Array(trimmed))
    }
}
