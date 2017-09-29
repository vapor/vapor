enum Error: Swift.Error {
    case cannotCreateContext
    case writeError
    case contextAlreadyCreated
    case noSSLContext
    case sslError(Int32)
    case invalidCertificate
}
