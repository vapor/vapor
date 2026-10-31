/// An address a socket is bound to, or that a peer connected from.
///
/// We defines its own address type to avoid exposing NIO or the HTTP Server in our API. This
/// is a limited API for just what we need, it will probably be replaced by the new Networking Types library
/// at some point in the future
public struct SocketAddress: Hashable, Sendable, CustomStringConvertible {
    /// Which family an address belongs to.
    ///
    /// Switch on this to decide how to read the payload: ``host`` and ``port`` are non-`nil` for
    /// ``ipv4`` and ``ipv6``, and ``pathname`` is non-`nil` for ``unixDomainSocket``.
    public enum Kind: Hashable, Sendable {
        case ipv4
        case ipv6
        case unixDomainSocket
    }

    /// The payload is kept behind a wrapper struct rather than exposed as an enum so that new
    /// address families can be added without breaking exhaustive switches downstream.
    enum Base: Hashable, Sendable {
        case ipv4(host: String, port: Int)
        case ipv6(host: String, port: Int)
        case unixDomainSocket(path: String)
    }

    let base: Base

    init(base: Base) {
        self.base = base
    }

    /// Creates an IPv4 address from an address and port that are already known to be valid.
    ///
    /// Use ``init(ipAddress:port:)`` to parse and validate an untrusted string instead.
    public static func ipv4(host: String, port: Int) -> Self {
        Self(base: .ipv4(host: host, port: port))
    }

    /// Creates an IPv6 address from an address and port that are already known to be valid.
    ///
    /// Use ``init(ipAddress:port:)`` to parse and validate an untrusted string instead.
    public static func ipv6(host: String, port: Int) -> Self {
        Self(base: .ipv6(host: host, port: port))
    }

    /// Creates the address of a UNIX domain socket at `path`.
    public static func unixDomainSocket(path: String) -> Self {
        Self(base: .unixDomainSocket(path: path))
    }

    /// Creates an address from an IP literal, returning `nil` if `ipAddress` is not one.
    ///
    /// Only literals are accepted — a hostname is never resolved, so this never performs I/O and
    /// is safe to call on any thread. Which of ``Kind/ipv4`` or ``Kind/ipv6`` results is decided by
    /// the literal itself.
    ///
    /// Parsing is deliberately stricter than the platform's `inet_pton`: octets with leading zeros
    /// and IPv6 zone indices are both refused, so the same string is accepted or rejected
    /// identically on every platform Vapor runs on.
    ///
    /// - Parameters:
    ///   - ipAddress: A dotted-quad IPv4 literal, or an IPv6 literal without a zone index.
    ///   - port: The port, stored as given and not range-checked.
    public init?(ipAddress: String, port: Int) {
        if Self.isIPv4Literal(ipAddress) {
            self = .ipv4(host: ipAddress, port: port)
        } else if Self.isIPv6Literal(ipAddress) {
            self = .ipv6(host: ipAddress, port: port)
        } else {
            return nil
        }
    }

    /// The family this address belongs to.
    public var kind: Kind {
        switch self.base {
        case .ipv4: .ipv4
        case .ipv6: .ipv6
        case .unixDomainSocket: .unixDomainSocket
        }
    }

    /// The host, or `nil` for a UNIX domain socket.
    public var host: String? {
        switch self.base {
        case .ipv4(let host, _), .ipv6(let host, _): host
        case .unixDomainSocket: nil
        }
    }

    /// The port, or `nil` for a UNIX domain socket.
    public var port: Int? {
        switch self.base {
        case .ipv4(_, let port), .ipv6(_, let port): port
        case .unixDomainSocket: nil
        }
    }

    /// The filesystem path of a UNIX domain socket, or `nil` for an IP address.
    public var pathname: String? {
        switch self.base {
        case .ipv4, .ipv6: nil
        case .unixDomainSocket(let path): path
        }
    }

    /// A human-readable description, matching the format `NIOCore.SocketAddress` uses.
    public var description: String {
        switch self.base {
        case .ipv4(let host, let port): "[IPv4]\(host):\(port)"
        case .ipv6(let host, let port): "[IPv6]\(host):\(port)"
        case .unixDomainSocket(let path): "[UDS]\(path)"
        }
    }
}

// MARK: - IP literal parsing

extension SocketAddress {
    /// Whether `string` is a dotted-quad IPv4 literal.
    static func isIPv4Literal(_ string: some StringProtocol) -> Bool {
        var octets = 0
        for field in string.split(separator: ".", omittingEmptySubsequences: false) {
            octets += 1
            guard octets <= 4, self.isIPv4Octet(field) else { return false }
        }
        return octets == 4
    }

    /// Whether `field` is a single decimal octet in the range `0...255`.
    private static func isIPv4Octet(_ field: some StringProtocol) -> Bool {
        let digits = field.utf8
        guard (1...3).contains(digits.count) else { return false }
        // Leading zeros are rejected. Darwin's `inet_pton` accepts them and glibc's does not, and
        // an octet like `010` reads as 8 to anything that treats a leading zero as octal and as 10
        // to anything that does not. Refusing them keeps the parse unambiguous rather than
        // platform-dependent, at the cost of turning away a spelling no proxy emits in practice.
        guard digits.count == 1 || digits.first != UInt8(ascii: "0") else { return false }

        var value = 0
        for digit in digits {
            guard (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(digit) else { return false }
            value = value * 10 + Int(digit - UInt8(ascii: "0"))
        }
        return value <= 255
    }

    /// Whether `string` is an IPv6 literal.
    ///
    /// Accepts the compressed `::` form and a trailing dotted-quad, and rejects a zone index
    /// (`fe80::1%en0`). Darwin's `inet_pton` accepts a zone, but it names a local interface rather
    /// than forming part of the address, so it is meaningless on a peer address read out of a
    /// forwarding header.
    static func isIPv6Literal(_ string: String) -> Bool {
        guard !string.contains("%") else { return false }

        var groupCount = 0
        var sawCompression = false
        var index = string.startIndex
        let end = string.endIndex

        if string.hasPrefix("::") {
            sawCompression = true
            index = string.index(index, offsetBy: 2)
            // `::` on its own is the all-zeros address.
            if index == end { return true }
        } else if string.hasPrefix(":") {
            // A single leading colon does not open a group.
            return false
        }

        while index < end {
            // Read one group, up to the next separator.
            let groupStart = index
            while index < end, string[index] != ":" {
                index = string.index(after: index)
            }
            let group = string[groupStart..<index]
            guard !group.isEmpty else { return false }

            if group.contains(".") {
                // A dotted-quad stands in for the final 32 bits, so it must come last.
                guard self.isIPv4Literal(group), index == end else { return false }
                groupCount += 2
            } else {
                guard self.isHexGroup(group) else { return false }
                groupCount += 1
            }

            if index == end { break }

            index = string.index(after: index)
            if index < end, string[index] == ":" {
                // `::` may compress a run of zero groups exactly once.
                guard !sawCompression else { return false }
                sawCompression = true
                index = string.index(after: index)
                if index == end { break }
            } else if index == end {
                // A trailing single colon does not open a group.
                return false
            }
        }

        // `::` pads the address out to 8 groups, so at least one must be left unwritten.
        // Without it, every group has to be spelled out.
        return sawCompression ? groupCount < 8 : groupCount == 8
    }

    /// Whether `group` is one to four hexadecimal digits.
    private static func isHexGroup(_ group: Substring) -> Bool {
        let digits = group.utf8
        guard (1...4).contains(digits.count) else { return false }
        return digits.allSatisfy {
            (UInt8(ascii: "0")...UInt8(ascii: "9")).contains($0)
                || (UInt8(ascii: "a")...UInt8(ascii: "f")).contains($0)
                || (UInt8(ascii: "A")...UInt8(ascii: "F")).contains($0)
        }
    }
}
