struct Signature {
    var variant: Variant
    var method: Method
    var parameters: [Parameter]

    init(variant: Variant, method: Method, parameters: [Parameter]) {
        self.variant = variant
        self.method = method
        self.parameters = parameters
    }
}

extension Signature {
    var wildcards: [Parameter.Wildcard] {
        return parameters.flatMap { parameter in
            if case .wildcard(let wildcard) = parameter {
                return wildcard
            }

            return nil
        }
    }

    var paths: [Parameter.Path] {
        return parameters.flatMap { parameter in
            if case .path(let path) = parameter {
                return path
            }

            return nil
        }
    }
}

/**
    Creates the function signature.
 
    <--- documentation -->
 
    /**
        Blah blah blah ...
    */

    public func get<T: StringInitializable>(_ p0: String, _ w0: T, handler: (Request, T) -> ResponseRepresentable)

                   <----- generic map ---->
                                            <----- list -------->
                                                                            handler input
                                                                             <--------->    <-- handler output -->
 
                                           <------------------- input ----------------->
    
    <-------------------------------------------- description ---------------------------------------------------->
*/
extension Signature: CustomStringConvertible {
    var description: String {
        return [
            documentation,
            "public func \(name)\(generics)(\(input))"
        ].joined(separator: "\n")
    }
}

extension Signature {
    var input: String {
        if parameters.count > 0 {
            return "\(list), \(handler)"
        } else {
            return handler
        }
    }

    var list: String {
        if
            parameters.count == 1,
            let first = parameters.first,
            case .path(let path) = first
        {
            return "_ \(path.name): String = \"\""
        } else {
            return parameters.map { parameter in
                var string = "_ \(parameter.name): "

                switch parameter {
                case .path(_):
                    string <<< "String"
                case .wildcard(let wildcard):
                    string <<< "\(wildcard.generic).Type"
                }

                return string
            }.joined(separator: ", ")
        }
    }

    var handler: String {
        return "handler: (\(handlerInput)) throws -> \(handlerOutput)"
    }

    var handlerInput: String {
        var items = ["HTTPRequest"]

        if variant == .socket {
            items.append("WebSocket")
        }

        items += wildcards.map { $0.generic }

        return items.joined(separator: ", ")
    }

    var handlerOutput: String {
        switch variant {
        case .socket:
            return "()"
        case .base:
            return "HTTPResponseRepresentable"
        }
    }

    var generics: String {
        if genericMap.characters.count == 0 {
            return ""
        }
        return "<\(genericMap)>"
    }

    var genericMap: String {
        return wildcards.map { wildcard in
            return "\(wildcard.generic): StringInitializable"
        }.joined(separator: ", ")
    }

    var name: String {
        switch variant {
        case .socket:
            return "socket"
        case .base:
            return method.lowercase
        }
    }
}
