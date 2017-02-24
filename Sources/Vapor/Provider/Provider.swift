import Core

/// Providers allow external projects to be easily
/// integrated into a Vapor droplet.
///
/// Simply add the provider using drop.addProvider(...)
///
///The Provider should take care of setting up any
///necessary configurations on itself and the Droplet.
public protocol Provider: ConfigInitializable {
    /// Called after the provider has initialized
    /// in the `addProvider` call.
    func boot(_: Droplet) throws

    /// Called before the Droplet begins serving
    /// which is @noreturn.
    func beforeRun(_: Droplet) throws
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
