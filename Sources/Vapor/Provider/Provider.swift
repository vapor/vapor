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
    public func afterInit(_ drop: Droplet) {
        //
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
