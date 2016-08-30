/**
    The source to load a configuration from.
*/
public enum Source {
    /**
        In memory configuration
    */
    case memory(name: String, config: Node)
    /**
        Load configuration from CommandLine.arguments. 
     
        --config:name.path=value
    */
    case commandLine
    /**
        All files in the given directory will be loaded into config.
     
        - JSON files will be parsed as JSON
        - Non-JSON files will be parsed as raw Bytes
        - SubDirectories will NOT be parsed
    */
    case directory(root: String)
}
