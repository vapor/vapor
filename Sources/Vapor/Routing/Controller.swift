/**
    Base controller class
*/
public class Controller: ApplicationInitializable {
    /// Access to the current Application instance
    public let app: Application

    public required init(application: Application) {
        self.app = application
    }
}
