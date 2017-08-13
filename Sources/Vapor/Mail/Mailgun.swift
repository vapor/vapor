import Core
import HTTP
import FormData
import Multipart
import Service
import SMTP
import URI

public struct MailgunConfig {
    public let domain: String
    public let apiKey: String
}

public struct MailgunRequest: JSONCodable {
    public let subject: String
    public var html: String?
    public var text: String?

    public init(subject: String, html: String? = nil, text: String? = nil) {
        self.subject = subject
        self.html = html
        self.text = text
    }
}

public final class Mailgun: MailProtocol {
    public let clientFactory: ClientFactoryProtocol
    public let apiURI: URI
    public let apiKey: String
    
    public init(
        config: MailgunConfig,
        client: ClientFactoryProtocol
    ) throws {
        self.apiURI = try URI("https://api.mailgun.net/v3/\(config.domain)/")
        self.clientFactory = client
        self.apiKey = config.apiKey
    }
    
    public func send(_ emails: [Email]) throws {
        try emails.forEach(_send)
    }
    
    private func _send(_ mail: Email) throws {
        let uri = apiURI.appendingPathComponent("messages")
        let req = Request(method: .post, uri: uri)
        
        let basic = "api:\(apiKey)".makeBytes().base64Encoded.makeString()
        req.headers["Authorization"] = "Basic \(basic)"

        var json = MailgunRequest(subject: mail.subject)
        switch mail.body.type {
        case .html:
            json.html = mail.body.content
        case .plain:
            json.text = mail.body.content
        }
        
        let fromName = mail.from.name ?? "Vapor Mailgun"
        let from = FormData.Field(
            name: "from",
            filename: nil,
            part: Part(
                headers: [:],
                body: "\(fromName) <\(mail.from.address)>".makeBytes()
            )
        )
        
        let to = FormData.Field(
            name: "to",
            filename: nil,
            part: Part(
                headers: [:],
                body: mail.to.map({ $0.address }).joined(separator: ", ").makeBytes()
            )
        )
        
        let subject = FormData.Field(
            name: "subject",
            filename: nil,
            part: Part(
                headers: [:],
                body: mail.subject.makeBytes()
            )
        )
        
        let bodyKey: String
        switch mail.body.type {
        case .html:
            bodyKey = "html"
        case .plain:
            bodyKey = "text"
        }
        
        let body = FormData.Field(
            name: bodyKey,
            filename: nil,
            part: Part(
                headers: [:],
                body: mail.body.content.makeBytes()
            )
        )
        
        req.formData = [
            "from": from,
            "to": to,
            "subject": subject,
            bodyKey: body
        ]
        
        if let replyTo = mail.extendedFields["h:Reply-To"] {
            let part = Part(headers: [:], body: replyTo.makeBytes())
            req.formData?["h:Reply-To"] = Field(name: "h:Reply-To", filename: nil, part: part)
        }
        
        let client = try clientFactory.makeClient(
            hostname: apiURI.hostname,
            port: apiURI.port ?? 443,
            securityLayer: .tls(EngineClient.defaultTLSContext())
        )
        let res = try client.respond(to: req)
        guard res.status.statusCode < 400 else {
            throw Abort(.badRequest)
        }
    }
}

// MARK: Service

extension Mailgun: ServiceType {
    /// See Service.serviceName
    public static var serviceName: String {
        return "mailgun"
    }

    /// See Service.serviceSupports
    public static var serviceSupports: [Any.Type] {
        return [MailProtocol.self]
    }

    /// See Service.make
    public static func makeService(for container: Container) throws -> Mailgun? {
        return try Mailgun(
            config: container.make(),
            client: container.make()
        )
    }
}
