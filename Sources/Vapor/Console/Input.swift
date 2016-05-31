///// Wrapper class around CLI input
//public class Input {
//    /// CLI arguments
//    public let arguments: [InputArgument]
//    private let namedArguments: [String: InputArgument]
//
//    /// CLI options
//    public let options: [InputOption]
//    private let namedOptions: [String: InputOption]
//
//    /**
//        Convenience initialize to create Input class with
//        process arguments
//
//        - parameter input: Optional input to initialize class with
//    */
//    public convenience init(input: [String] = Process.arguments) {
//        guard input.count > 0 else {
//            self.init(arguments: [], options: [ ])
//            return
//        }
//
//        var arguments: [InputArgument] = []
//        var options: [InputOption] = []
//
//        var raw = input
//        raw.removeFirst()
//
//        for (index, argument) in raw.enumerated() {
//            if argument.hasPrefix("-") {
//                let components = argument.split("=")
//
//                if components.count == 1 {
//                    options.append(InputOption(
//                        components[0],
//                        mode: .None
//                    ))
//                } else {
//                    options.append(InputOption(
//                        components[0],
//                        mode: .Optional,
//                        value: components[1]
//                    ))
//                }
//            } else {
//                arguments.append(InputArgument(
//                    String(index),
//                    mode: .Optional,
//                    value: argument
//                ))
//            }
//        }
//
//        self.init(arguments: arguments, options: options)
//    }
//
//     /**
//        Initialize input
//        - parameter arguments: CLI arguments
//        - parameter options: CLI options
//    */
//   public init(arguments: [InputArgument], options: [InputOption]) {
//        self.arguments = arguments
//        self.options = options
//
//        var namedArguments: [String: InputArgument] = [:]
//        for argument in arguments {
//            namedArguments[argument.name] = argument
//        }
//        self.namedArguments = namedArguments
//
//        var namedOptions: [String: InputOption] = [:]
//        for option in options {
//            namedOptions[option.name] = option
//        }
//        self.namedOptions = namedOptions
//    }
//
//    /**
//        Get the value of an argument
//        - parameter name: Name of the argument to get value of
//        - returns: Argument value, if present
//    */
//    public func argument(name: String) -> String? {
//        return namedArguments[name]?.value
//    }
//
//    /**
//        Get the value of an option
//        - parameter name: Name of the option to get value of
//        - returns: Option value, if present
//    */
//    public func option(name: String) -> String? {
//        return namedOptions[name]?.value
//    }
//
//    /**
//        Check if option is present
//        - parameter name: Name of option to check for
//        - returns: True if option is present, false if not
//    */
//    public func hasOption(name: String) -> Bool {
//        return namedOptions[name] != nil
//    }
//
//}
