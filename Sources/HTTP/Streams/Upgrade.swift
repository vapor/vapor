import TCP

let onUpgradeKey = "http:on-upgrade"

public typealias OnUpgrade = (TCPClient) -> ()

extension Message {
    public var onUpgrade: OnUpgrade? {
        get { return extend.storage[onUpgradeKey] as? OnUpgrade }
        set { return extend.storage[onUpgradeKey] = newValue }
    }
}
