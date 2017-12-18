import Async
import Bits
import COpenSSL
import COperatingSystem
import TCP
import TLS

/// COpenSSL implemented TLS socket.
public final class OpenSSLSocket: TLSSocket {
    /// See TLSSocket.descriptor
    public var descriptor: Int32 {
        return tcp.descriptor
    }

    /// The underlying OpenSSL session
    typealias CSSL = UnsafeMutablePointer<SSL>

    /// Handle to the CSSL OpenSSL session
    internal let cSSL: CSSL

    /// The underlying TCP socket.
    private let tcp: TCPSocket

    /// True if the handshake has completed
    private var handshakeCompleted: Bool

    /// Create a new OpenSSL socket with the supplied method.
    public init(tcp: TCPSocket, method: OpenSSLMethod, side: OpenSSLSide) throws {
        let method = method.method(side: .client)

        guard OpenSSLSettings.initialized, let context = SSL_CTX_new(method) else {
            throw OpenSSLError(identifier: "createContext", reason: "SSL context creation failed.")
        }

        SSL_CTX_ctrl(context, SSL_CTRL_MODE, SSL_MODE_AUTO_RETRY, nil)
        SSL_CTX_ctrl(
            context,
            SSL_CTRL_OPTIONS,
            SSL_OP_NO_SSLv2
                | SSL_OP_NO_SSLv3
                | SSL_OP_NO_COMPRESSION,
            nil
        )
        SSL_CTX_set_verify(context, SSL_VERIFY_NONE, nil)

        guard SSL_CTX_set_cipher_list(context, "DEFAULT") == 1 else {
            throw OpenSSLError(identifier: "setCipherList", reason: "Setting cipher list on SSL context failed.")
        }

        guard let ssl = SSL_new(context) else {
            throw OpenSSLError(identifier: "createSession", reason: "Creating SSL session failed.")
        }

        self.cSSL = ssl
        self.tcp = tcp
        handshakeCompleted = false
        try assert(SSL_set_fd(ssl, tcp.descriptor), identifier: "setDescriptor")
    }

    /// See TLSSocket.read
    public func read(into buffer: UnsafeMutableBufferPointer<UInt8>) throws -> SocketReadStatus {
        let bytesRead = SSL_read(cSSL, buffer.baseAddress!, Int32(buffer.count))
        if bytesRead <= 0 {
            switch SSL_get_error(cSSL, bytesRead) {
            case SSL_ERROR_WANT_READ, SSL_ERROR_WANT_WRITE, SSL_ERROR_WANT_CONNECT:
                return .wouldBlock
            default:
                throw makeError(status: bytesRead, identifier: "read")
            }
        }
        return .read(count: Int(bytesRead))
    }

    /// See TLSSocket.write
    public func write(from buffer: UnsafeBufferPointer<UInt8>) throws -> SocketWriteStatus {
        guard buffer.count > 0 else {
            // attempts to write something less than 0
            // will cause an ssl write error
            return .wrote(count: 0)
        }

        let bytesSent = SSL_write(cSSL, buffer.baseAddress!, Int32(buffer.count))
        if bytesSent <= 0 {
            throw makeError(status: bytesSent, identifier: "write")
        }
        return .wrote(count: Int(bytesSent))
    }

    /// See TLSSocket.close
    public func close() {
        tcp.close()
    }

    /// See DispatchSocket.isPrepared
    public var isPrepared: Bool {
        return handshakeCompleted
    }

    /// See DispatchSocket.prepareSocket
    public func prepareSocket() throws {
        try handshake()
    }

    /// Runs the SSL handshake, regardless of client or server
    public func handshake() throws {
        let result = SSL_do_handshake(cSSL)
        let code = SSL_get_error(cSSL, result)
        if result >= 0 {
            handshakeCompleted = true
        } else {
            guard
                code == SSL_ERROR_WANT_READ ||
                code == SSL_ERROR_WANT_WRITE ||
                code == SSL_ERROR_WANT_CONNECT
            else {
                throw makeError(status: result, identifier: "handshake")
            }
        }
    }

    deinit {
        SSL_free(cSSL)
    }
}


extension OpenSSLSocket {
    /// Asserts an OpenSSL method returns succesfully or throws an error.
    fileprivate func assert(
        _ returnCode: Int32,
        identifier: String,
        file: String = #file,
        function: String = #function,
        line: UInt = #line,
        column: UInt = #column
    ) throws {
        if returnCode != 1 {
            throw makeError(
                status: returnCode,
                identifier: identifier,
                file: file,
                function: function,
                line: line,
                column: column
            )
        }
    }

    /// Creates an error for a supplied return code using
    /// the OpenSSL socket's current SSL session.
    fileprivate func makeError(
        status returnCode: Int32,
        identifier: String,
        file: String = #file,
        function: String = #function,
        line: UInt = #line,
        column: UInt = #column
    ) -> OpenSSLError {
        let reason: String

        let res = SSL_get_error(cSSL, returnCode)
        switch res {
        case SSL_ERROR_ZERO_RETURN:
            reason = "The TLS/SSL connection has been closed."
        case
        SSL_ERROR_WANT_READ,
        SSL_ERROR_WANT_WRITE,
        SSL_ERROR_WANT_CONNECT,
        SSL_ERROR_WANT_ACCEPT:
            reason = "The operation did not complete; the same TLS/SSL I/O function should be called again later."
        case SSL_ERROR_WANT_X509_LOOKUP:
            reason = "The operation did not complete because an application callback set by SSL_CTX_set_client_cert_cb() has asked to be called again."
        case SSL_ERROR_SYSCALL:
            reason = String(validatingUTF8: strerror(errno)) ?? "System call error"
        case SSL_ERROR_SSL:
            let bio = BIO_new(BIO_s_mem())

            defer {
                BIO_free(bio)
            }

            ERR_print_errors(bio)
            let written = BIO_number_written(bio)

            var buffer: [Int8] = Array(repeating: 0, count: Int(written) + 1)
            reason = buffer.withUnsafeMutableBufferPointer { buf in
                BIO_read(bio, buf.baseAddress, Int32(written))
                return String(validatingUTF8: buf.baseAddress!) ?? "Unknown"
            }
        default:
            if
                let errPointer = ERR_reason_error_string(ERR_get_error()),
                let errString = String(validatingUTF8: errPointer)
            {
                reason = errString
            } else {
                reason = "An unknown error in the OpenSSL library occurred."
            }
        }

        return .init(
            identifier: identifier,
            reason: reason,
            file: file,
            function: function,
            line: line,
            column: column
        )
    }
}
