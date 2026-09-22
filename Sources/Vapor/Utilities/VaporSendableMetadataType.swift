#if compiler(>=6.2)
public typealias VaporSendableMetatype = SendableMetatype
#else
public typealias VaporSendableMetatype = Any
#endif
