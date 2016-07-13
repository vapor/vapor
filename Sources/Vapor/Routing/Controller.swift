/**
    Base controller class
*/
public class Controller: DropletInitializable {
    var droplet: Droplet
    public required init(droplet: Droplet) {
        self.droplet = droplet
    }
}
