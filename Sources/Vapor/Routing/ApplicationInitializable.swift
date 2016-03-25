/**
    Controllers that conform to this protocol
    will get the requesting application passed
    as an initialization parameter.
*/
public protocol ApplicationInitializable {
    init(application: Application)
}
