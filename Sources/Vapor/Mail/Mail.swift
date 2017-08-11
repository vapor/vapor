import SMTP
import Foundation
import Transport
import Service
import Sockets

/// Defines objects capable of transmitting emails
public protocol MailProtocol {
    /// Send the supplied emails
    func send(_ emails: [Email]) throws
}

extension MailProtocol {
    /// Sends a single email
    public func send(_ email: Email) throws {
        try send([email])
    }
}

/// SMTP Mailer to use basic SMTP Protocols
public final class SMTPMailer: MailProtocol {
    let scheme: String
    let hostname: String
    let port: Transport.Port
    let credentials: SMTPCredentials

    public init(scheme: String, hostname: String, port: Transport.Port, credentials: SMTPCredentials) {
        self.scheme = scheme
        self.hostname = hostname
        self.port = port
        self.credentials = credentials
    }

    public func send(_ emails: [Email]) throws {
        let client = try makeClient()
        try client.send(emails, using: credentials)
    }

    private func makeClient() throws -> SMTPClient<TCPInternetSocket> {
        let socket = try TCPInternetSocket(scheme: scheme, hostname: hostname, port: port)
        return try SMTPClient(socket)
    }
}

extension SMTPMailer {
    /// https://sendgrid.com/
    ///
    /// Credentials:
    /// https://app.sendgrid.com/settings/credentials
    public static func makeSendGrid(with credentials: SMTPCredentials) -> SMTPMailer {
        return SMTPMailer(
            scheme: "smtps",
            hostname: "smtp.sendgrid.net",
            port: 465,
            credentials: credentials
        )
    }

    /// https://www.digitalocean.com/community/tutorials/how-to-use-google-s-smtp-server
    ///
    /// Credentials:
    /// user: Your full Gmail or Google Apps email address (e.g. example@gmail.com or example@yourdomain.com)
    /// pass: Your Gmail or Google Apps email password
    public static func makeGmail(with credentials: SMTPCredentials) -> SMTPMailer {
        return SMTPMailer(
            scheme: "smtps",
            hostname: "smtp.gmail.com",
            port: 465,
            credentials: credentials
        )
    }

    /// https://mailgun.com/
    ///
    /// Credentials:
    /// https://mailgun.com/app/domains
    public static func makeMailgun(with credentials: SMTPCredentials) -> SMTPMailer {
        return SMTPMailer(
            scheme: "smtps",
            hostname: "smtp.mailgun.org",
            port: 465,
            credentials: credentials
        )
    }
}

/// To avoid forcing users to deal with an optional on mailer 
/// which would be annoying long term, this is a place holder
/// that simply throws, but provides info on how to setup
/// a proper mailer in the error
final class UnimplementedMailer: MailProtocol {
    func send(_ emails: [Email]) throws {
        throw MailerError.unimplemented
    }
}

enum MailerError: Debuggable {
    case unimplemented
}

extension MailerError {
    var identifier: String {
        return "unimplemented"
    }

    var reason: String {
        return "mailer hasn't been setup yet"
    }

    var possibleCauses: [String] {
        return [
            "a mailer hasn't been setup yet on droplet"
        ]
    }

    var suggestedFixes: [String] {
        return [
            "add a mailer to your droplet, for example `drop.mailer = SMTPMailer.makeGmail(with: creds)`"
        ]
    }
}
