/** Interface for reading/requiring CLI options */
public class InputOption {
    ///Name of the option
    public let name: String

    ///Option mode
    public let mode: ValueMode

    ///Value of the option, if present
    public let value: String?

    ///Help for the option
    public let help: String?

    ///Mode for the option
    public enum ValueMode {
        ///Indicates this option is a boolean flag and should have no value
        case None
        ///Indicates this option is required
        case Required
        ///Indicates this option is optional and may or may not be present
        case Optional
    }

    /**
        Initialize the option
        - parameter name: Name of the option
        - parameter mode: Mode for the option
        - parameter help: Optional help string
        - parameter value: Optional default value
    */
    public init(_ name: String, mode: ValueMode, help: String? = nil, value: String? = nil) {
        self.mode = mode
        self.help = help
        self.value = mode == .None ? nil : value

        if name.hasPrefix("--") {
            self.name = name[name.startIndex.advanced(by: 2)..<name.endIndex]
        } else if name.hasPrefix("-") {
            self.name = name[name.startIndex.advanced(by: 1)..<name.endIndex]
        } else {
            self.name = name
        }
    }

}

extension InputOption: CustomStringConvertible {

    ///Option description
    public var description: String {
        if let value = value {
            return name + "=" + value
        } else {
            return name
        }
    }

}
