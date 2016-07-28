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
    func beforeServe(_: Droplet)
}

extension Provider {
    public var name: String {
        let type = "\(self.dynamicType)"
        guard let characters = type.characters.split(separator: " ").first else {
            return "Provider"
        }

        let trimmed = Array(characters).trimmed(["("])

        return String(Array(trimmed))
    }
}
