//
//  Input.swift
//  Vapor
//
//  Created by Shaun Harrison on 2/20/16.
//

///Wrapper class around CLI input
public class Input {
    ///CLI arguments
    public let arguments: [InputArgument]

    ///CLI options
    public let options: [InputOption]

    /**
        Initialize input
        - parameter input: Optional input to initialize class with
    */
    public init(input: [String] = Process.arguments) {
        guard input.count > 0 else {
            self.arguments = []
            self.options = []
            return
        }

        var arguments = Array<InputArgument>()
        var options = Array<InputOption>()

        var raw = input
        raw.removeFirst()

        for (index, argument) in raw.enumerated() {
            if argument.hasPrefix("-") {
                let components = argument.split("=")

                if components.count == 1 {
                    options.append(InputOption(
                        components[0],
                        mode: .None
                    ))
                } else {
                    options.append(InputOption(
                        components[0],
                        mode: .Optional,
                        value: components[1]
                    ))
                }
            } else {
                arguments.append(InputArgument(
                    String(index),
                    mode: .Optional,
                    value: argument
                ))
            }
        }

        self.arguments = arguments
        self.options = options
    }

    /**
        Get the value of an option
        - parameter name: Name of the option to get value of
        - returns: Option value if present
    */
    public func option(name: String) -> String? {
        for option in options {
            if option.name == name {
                return option.value
            }
        }

        return nil
    }

    /**
        Check if option is present
        - parameter name: Name of option to check for
        - returns: True if option is present, false if not
    */
    public func hasParameterOption(name: String) -> Bool {
        for option in options {
            if option.name == name {
                return true
            }
        }

        return false
    }

}
