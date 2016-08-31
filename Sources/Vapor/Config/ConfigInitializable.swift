@_exported import Settings

/**
    Allows types to be instantiated from
    data contained in the Config directories.
 
    This is especially useful for types like Provider
    that often need configuration values to
    initialize. These values can be stored in
    the Config directories instead of the source code.
*/
public protocol ConfigInitializable {
    init(config: Settings.Config) throws
}
