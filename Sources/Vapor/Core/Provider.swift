/**
    Providers allow external projects to be easily
    integrated into a Vapor application.

    Simply append a dependencies provider to the Application's
    `providers` array.

    The Provider should take care of setting up any
    necessary configurations on itself and the Application.
*/
public protocol Provider {
    func boot(with application: Application)
}
