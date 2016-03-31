//
//  Input.swift
//  Vapor
//
//  Created by Shaun Harrison on 2/20/16.
//

public class Input {
    public let arguments: [InputArgument]
    public let options: [InputOption]

    public init() {
        var arguments = Array<InputArgument>()
        var options = Array<InputOption>()

        var raw = Process.arguments
        raw.removeFirst()

        for (index, argument) in raw.enumerated() {
            if argument.hasPrefix("-") {
                let components = argument.split("=")

                if components.count == 1 {
                    options.append(InputOption(components[0], mode: .None))
                } else {
                    options.append(InputOption(components[0], mode: .Optional, value: components[1]))
                }
            } else {
                arguments.append(InputArgument(String(index), mode: .Optional, value: argument))
            }
        }

        self.arguments = arguments
        self.options = options
    }

    public func option(name: String) -> String? {
        for option in options {
            if option.name == name {
                return option.value
            }
        }

        return nil
    }

    public func hasParameterOption(name: String) -> Bool {
        for option in options {
            if option.name == name {
                return true
            }
        }

        return false
    }

}
