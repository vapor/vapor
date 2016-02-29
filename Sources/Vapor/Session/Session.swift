/**
 A type conforming to `Session` is used for storing key/value data
 into a particular session. 
 */
public protocol Session: class {
    subscript(key: String) -> String? { get set }
}
