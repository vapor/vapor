import Configs

extension UnimplementedMailer: ConfigInitializable {
    public convenience init(config: Config) throws {
        self.init()
    }
}
