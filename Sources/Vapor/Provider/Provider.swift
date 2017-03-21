import Core

/// Providers allow external projects to be easily
/// integrated into a Vapor droplet.
///
/// Simply add the provider using drop.addProvider(...)
///
///The Provider should take care of setting up any
///necessary configurations on itself and the Droplet.
public protocol Provider: ConfigInitializable {
    /// This should be the name of the actual repository
    /// that contains the Provider.
    /// 
    /// this will be used for things like providing 
    /// resources
    ///
    /// this will default to stripped camel casing, 
    /// for example MyProvider will become `my-provider`
    /// if your Provider is providing resources
    /// it is HIGHLY recommended to provide a static let
    /// for performance considerations
    static var repositoryName: String { get }

    /// Called after the provider has initialized
    /// in the `addProvider` call.
    func boot(_: Droplet) throws

    /// Called before the Droplet begins serving
    /// which is @noreturn.
    func beforeRun(_: Droplet) throws
}

extension Provider {
    public static var name: String {
        let type = "\(self)"
        guard let characters = type.characters.split(separator: " ").first else {
            return "Provider"
        }

        let trimmed = Array(characters).trimmed(["("])

        return String(Array(trimmed))
    }

    public var name: String {
        return type(of: self).name
    }
}

extension Provider {
    public static var repositoryName: String {
        var module = String(reflecting: self)
            .makeBytes()
            .split(separator: .period)
            .first
            ?? []

        if module[0...4] == [.V, .a, .p, .o, .r] {
            module = module.dropFirst(5)
            module += [.hyphen, .p, .r, .o, .v, .i, .d, .e, .r]
        }

        return module.removingCamelCasing().makeString()
    }
}

extension Sequence where Iterator.Element == Byte {
    fileprivate func removingCamelCasing() -> Bytes {
        var result = Bytes()
        enumerated().forEach { idx, byte in
            switch byte {
            case .A ... .Z where idx != 0:
                result.append(.hyphen)
            default:
                break
            }
            result.append(byte)
        }
        return result.lowercased
    }
}
