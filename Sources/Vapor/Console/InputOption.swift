//
//  InputOption.swift
//  Vapor
//
//  Created by Shaun Harrison on 2/20/16.
//

public class InputOption {
    public let name: String
    public let mode: ValueMode
    public let value: String?
    public let help: String?

    public enum ValueMode {
        case None
        case Required
        case Optional
    }

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

    public var description: String {
        if let value = value {
            return name + "=" + value
        } else {
            return name
        }
    }

}
