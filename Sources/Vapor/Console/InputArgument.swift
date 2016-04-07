/** Interface for reading/requiring CLI arguments */
public class InputArgument {
    ///Name of the argument
    public let name: String

    ///Argument mode
    public let mode: ValueMode

    ///Value of the argument, if present
    public let value: String?

    ///Help for the option
    public let help: String?

    ///Mode for the argument
    public enum ValueMode {
        ///Indicates this argument is required and must have a value
        case Required
        ///Indicates this argument is optional and may or may not be present
        case Optional
    }

    /**
        Initialize the argument
        - parameter name: Name of the argument
        - parameter mode: Mode for the argument
        - parameter help: Optional help string
        - parameter value: Optional default value
    */
    public init(_ name: String, mode: ValueMode, help: String? = nil, value: String? = nil) {
        self.name = name
        self.mode = mode
        self.help = help
        self.value = value
    }

}

extension InputArgument: CustomStringConvertible {

    ///Argument description
    public var description: String {
        if let value = value {
            return name + "=" + value
        } else {
            return name
        }
    }

}
