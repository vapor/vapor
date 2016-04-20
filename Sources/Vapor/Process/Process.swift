import Foundation

extension Process {

    /**
     Returns the string value of an
     argument passed to the executable
     in the format --name=value

     - parameter argument: the name of the argument to get the value for
     - parameter arguments: arguments to search within.  Primarily used for testing through injection

     - returns: the value matching the argument if possible
     */
    public static func valueFor(argument name: String, inArguments arguments: [String] = NSProcessInfo.processInfo().arguments) -> String? {
        for argument in arguments where argument.hasPrefix("--\(name)=") {
            return argument.split(byString: "=").last
        }
        return nil
    }
}

/*
 /// Command-line arguments for the current process.
 public enum Process {
 /// Return an array of string containing the list of command-line arguments
 /// with which the current process was invoked.
 internal static func _computeArguments() -> [String] {
 var result: [String] = []
 let argv = unsafeArgv
 for i in 0..<Int(argc) {
 let arg = argv[i]!
 let converted = String(cString: arg)
 result.append(converted)
 }
 return result
 }

 @_versioned
 internal static var _argc: CInt = CInt()

 @_versioned
 internal static var _unsafeArgv:
 UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?
 = nil

 /// Access to the raw argc value from C.
 public static var argc: CInt {
 return _argc
 }

 /// Access to the raw argv value from C. Accessing the argument vector
 /// through this pointer is unsafe.
 public static var unsafeArgv:
 UnsafeMutablePointer<UnsafeMutablePointer<Int8>?> {
 return _unsafeArgv!
 }

 /// Access to the swift arguments, also use lazy initialization of static
 /// properties to safely initialize the swift arguments.
 ///
 /// NOTE: we can not use static lazy let initializer as they can be moved
 /// around by the optimizer which will break the data dependence on argc
 /// and argv.
 public static var arguments: [String] {
 let argumentsPtr = UnsafeMutablePointer<AnyObject?>(
 Builtin.addressof(&_swift_stdlib_ProcessArguments))

 // Check whether argument has been initialized.
 if let arguments = _stdlib_atomicLoadARCRef(object: argumentsPtr) {
 return (arguments as! _Box<[String]>).value
 }

 let arguments = _Box<[String]>(_computeArguments())
 _stdlib_atomicInitializeARCRef(object: argumentsPtr, desired: arguments)

 return arguments.value
 }
 }
 */
