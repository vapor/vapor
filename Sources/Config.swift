import Foundation

public class Config {
    
    public static var workDir = "./" {
        didSet {
            if !self.workDir.hasSuffix("/") {
                self.workDir += "/"
            }
        }
    }
    
}