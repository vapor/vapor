import Configs

/**
    The source to load a configuration from.
*/
public enum Source {
    /**
        In memory configuration
    */
    case memory(config: Config)
    /**
        Load configuration from CommandLine.arguments. 
     
        --config:name.path=value
    */
    case commandLine(arguments: [String])
}
