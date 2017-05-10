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
    
    /// The location of the public directory
    /// _relative_ to the root of the provider package.
    static var publicDir: String { get }
    
    /// The location of the views directory
    /// _relative_ to the root of the provider package.
    static var viewsDir: String { get }
    
    /// Called after the provider has initialized
    /// in the `Config.addProvider` call.
    func boot(_ config: Config) throws

    /// Called after the Droplet has initialized.
    func boot(_ droplet: Droplet) throws

    /// Called before the Droplet begins serving
    /// which is @noreturn.
    func beforeRun(_ droplet: Droplet) throws
}

// MARK: Optional

extension Provider {
    public static var publicDir: String {
        return "Public"
    }
    
    public static var viewsDir: String {
        return "Resources/Views"
    }
}
