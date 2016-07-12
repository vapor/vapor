/**
    Base controller class
*/
//public typealias Controller = protocol<DropletInitializable, ResourceController>

public class Controller: DropletInitializable {
    var droplet: Droplet
    public required init(droplet: Droplet) {
        self.droplet = droplet
    }
}
