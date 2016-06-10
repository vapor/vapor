// TODO: Temporary until C7 is updated
extension URIParser {
    public struct URI {
        public struct UserInfo {
            // TODO: Should auth and username be non-optional? There's a difference between "" and nil
            public var username: String
            public var password: String

            public init(username: String, password: String) {
                self.username = username
                self.password = password
            }
        }

        public var scheme: String?
        public var userInfo: UserInfo?
        public var host: String?
        public var port: Int?
        public var path: String?
        public var query:  String?
        public var fragment: String?

        public init(scheme: String? = nil,
                    userInfo: UserInfo? = nil,
                    host: String? = nil,
                    port: Int? = nil,
                    path: String? = nil,
                    query: String? = nil,
                    fragment: String? = nil) {
            self.scheme = scheme
            self.userInfo = userInfo
            self.host = host
            self.port = port
            self.path = path
            self.query = query
            self.fragment = fragment
        }
    }
}
