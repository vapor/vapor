import Vapor
import Redbird

public final class Provider: Vapor.Provider {
    public let provided: Providable

    public enum Error: Swift.Error {
        case invalidRedisConfig(String)
    }

    public init(address: String, port: Int, password: String?) throws {
        let config = RedbirdConfig(address: address, port: UInt16(port), password: password)
        let redbird = try Redbird(config: config)
        provided = Providable(cache: RedisCache(redbird: redbird))
    }

    public convenience init(config: Config) throws {
        guard let redis = config["redis"].object else {
            throw Error.invalidRedisConfig("No redis.json file.")
        }

        guard let address = redis["address"].string else {
            throw Error.invalidRedisConfig("No address.")
        }

        guard let port = redis["port"].int else {
            throw Error.invalidRedisConfig("No port.")
        }

        let password = redis["password"].string

        try self.init(address: address, port: port, password: password)
    }

    public func afterInit(_ droplet: Droplet) {

    }


    public func beforeServe(_ droplet: Droplet) {

    }
}
