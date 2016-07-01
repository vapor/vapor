/**
    Base controller class
*/
//public typealias Controller = protocol<ApplicationInitializable, ResourceController>

public class Controller: ApplicationInitializable {
    var droplet: Droplet
    public required init(droplet: Droplet) {
        self.droplet = droplet
    }
}
