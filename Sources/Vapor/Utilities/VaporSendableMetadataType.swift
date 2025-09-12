#if swift(>=6.2)
public typealias VaporSendableMetatype = Any
#else
public typealias VaporSendableMetatype = SendableMetatype
#endif
