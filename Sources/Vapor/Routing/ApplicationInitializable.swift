/**
    Controllers that conform to this protocol
    will get the requesting application passed
    as an initialization parameter.
*/
public protocol ApplicationInitializable {
    init(droplet: Application)
}

public typealias DropletInitializable = ApplicationInitializable
