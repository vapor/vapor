/**
    Controllers that conform to this protocol
    will get the requesting droplet passed
    as an initialization parameter.
*/
public protocol DropletInitializable {
    init(droplet: Droplet)
}
