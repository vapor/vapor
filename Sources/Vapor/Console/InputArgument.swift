//
//  InputArgument.swift
//  Vapor
//
//  Created by Shaun Harrison on 2/20/16.
//

public class InputArgument {
    public let name: String
    public let mode: ValueMode
    public let value: String?
    public let help: String?

    public enum ValueMode {
        case Required
        case Optional
    }

    public init(_ name: String, mode: ValueMode, help: String? = nil, value: String? = nil) {
        self.name = name
        self.mode = mode
        self.help = help
        self.value = value
    }

}

extension InputArgument: CustomStringConvertible {

    public var description: String {
        if let value = value {
            return name + "=" + value
        } else {
            return name
        }
    }

}
