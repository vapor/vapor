#if !os(Linux)

import Foundation

let GENERIC_MAP = ["T", "U", "V", "W", "X"]
let MAX_PARAMS = GENERIC_MAP.count

struct Func: CustomStringConvertible {
    enum Method {
        case get, post, put, patch, delete, options
    }
    
    var method: Method
    var params: [Param]
    
    var description: String {
       
        
        
        let wildcards = params.filter { param in
            return param.type == .Wildcard
        }
        
        
        var f = ""
        f += "\tpublic func "
        f += "\(method)".lowercased()
        
        //generic <>
        if wildcards.count > 0 {
            let genericsString = wildcards.map { wildcard in
                return "\(wildcard.generic): StringInitializable"
            }.joined(separator: ", ")
            
            f += "<\(genericsString)>"
        }
        
        let paramsString: String
        
        if let param = params.first where params.count == 1 && param.type == .Path {
            paramsString = "_ \(param) = \"/\""
        } else {
            paramsString = params
                .map { param in "_ \(param)" }
                .joined(separator: ", ")
        }

        f += "(\(paramsString), handler: (Request"
        
        //handler params
        if wildcards.count > 0 {
            let genericsString = wildcards.map { wildcard in
                return wildcard.generic
            }.joined(separator: ", ")
            
            f += ", \(genericsString)) throws -> ResponseRepresentable) {\n"

        } else {
            f += ") throws -> ResponseRepresentable) {\n"
        }
        
        let pathString = params.map { param in
            if param.type == .Wildcard {
                return ":\(param.name)"
            }
            
            return "\\(\(param.name))"
        }.joined(separator: "/")
        
        f += "\t\tself.add(.\(method), path: \"\(pathString)\") { request in\n"
        
        //function body
        if wildcards.count > 0 {
            //grab from request params
            for wildcard in wildcards {
                f += "\t\t\tguard let v\(wildcard.name) = request.parameters[\"\(wildcard.name)\"] else {\n"
                f += "\t\t\t\tthrow Abort.badRequest\n"
                f += "\t\t\t}\n"
            }
            
            f += "\n"
            
            //try
            for wildcard in wildcards {
                f += "\t\t\tlet e\(wildcard.name) = try \(wildcard.generic)(from: v\(wildcard.name))\n"
            }
            
            f += "\n"
            
            //ensure conversion worked
            for wildcard in wildcards {
                f += "\t\t\tguard let c\(wildcard.name) = e\(wildcard.name) else {\n"
                f += "\t\t\t\tthrow Abort.invalidParameter(\"\(wildcard.name)\", \(wildcard.generic).self)\n"
                f += "\t\t\t}\n"
            }
            
            f += "\n"
            
            
            let wildcardString = wildcards.map { wildcard in
                return "c\(wildcard.name)"
            }.joined(separator: ", ")
            
            f += "\t\t\treturn try handler(request, \(wildcardString))\n"
            
        } else {
            
            f += "\t\t\treturn try handler(request)\n"
        }
        
        f += "\t\t}\n"
        
        f += "\t}"
        return f
    }
}

func paramTypeCount(_ type: Param.`Type`, params: [Param]) -> Int {
    var i = 0
    
    for param in params {
        if param.type == type {
            i += 1
        }
    }
    
    return i
}

struct Param: CustomStringConvertible {
    var name: String
    var type: Type
    var generic: String
    
    var description: String {
        var description = "\(name): "
        if type == .Wildcard {
            description += "\(generic).Type"
        } else {
            description += "String"
        }
        return description
    }
    
    enum `Type` {
        case Path, Wildcard
    }
    static var types: [Type] = [.Path, .Wildcard]
    
    static func addTypePermutations(toArray paramsArray: [[Param]]) -> [[Param]] {
        var permParamsArray: [[Param]] = []
        
        for paramArray in paramsArray {
            for type in Param.types {
                var mutableParamArray = paramArray
                
                var name = ""
                if type == .Wildcard {
                    name = "w"
                } else {
                    name = "p"
                }
                
                let count = paramTypeCount(type, params: paramArray)
                name += "\(count)"
                
                let generic = GENERIC_MAP[count]
                
                let param = Param(name: name, type: type, generic: generic)
                
                mutableParamArray.append(param)
                permParamsArray.append(mutableParamArray)
            }
        }
        
        return permParamsArray
    }
}




var paramPermutations: [[Param]] = []

for paramCount in 0...MAX_PARAMS {
    var perms: [[Param]] = [[]]
    for _ in 0..<paramCount {
        perms = Param.addTypePermutations(toArray: perms)
    }
    
    paramPermutations += perms
}

var generated = "// *** GENERATED CODE ***\n"
generated += "// \(NSDate())\n"
generated += "//\n"
generated += "// DO NOT EDIT THIS FILE OR CHANGES WILL BE OVERWRITTEN\n\n"
generated += "extension RouteBuilder {\n\n"

for method: Func.Method in [.get, .post, .put, .patch, .delete, .options] {
    for params in paramPermutations {
        guard params.count > 0 else {
            continue
        }
        
        var f = Func(method: method, params: params)
        generated += "\(f)\n\n"
    }
}

generated += "}\n"

if Process.arguments.count < 2 {
    fatalError("Please pass $SRCROOT as a parameter")
}

let path = Process.arguments[1].replacingOccurrences(of: "XcodeProject", with: "")
let url = NSURL(fileURLWithPath: path + "/Sources/Vapor/Core/Generated.swift")

do{
    // writing to disk
    try generated.write(to: url, atomically: true, encoding: NSUTF8StringEncoding)
    print("File created at \(url)")
} catch let error as NSError {
    print("Error writing generated file at \(url)")
    print(error.localizedDescription)
}

#endif