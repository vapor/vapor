import Core
import Dispatch
import TCP

/// Serialized HTTP message, including
/// optional upgrade closure.
public struct SerializedMessage {
    public let message: DispatchData
    public let onUpgrade: OnUpgrade?
}
