//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2021 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

#if canImport(Network)
import Foundation
public import Network
public import Security

/// Wrapper for NIO transport services TLS options
public struct TSTLSOptions: Sendable {
    public struct Error: Swift.Error, Equatable {
        enum _Internal: Equatable {
            case invalidFormat
            case interactionNotAllowed
            case verificationFailed
        }

        private let value: _Internal
        init(_ value: _Internal) {
            self.value = value
        }

        // invalid format
        public static var invalidFormat: Self { .init(.invalidFormat) }
        // unable to import p12 as no interaction is allowed
        public static var interactionNotAllowed: Self { .init(.interactionNotAllowed) }
        // MAC verification failed during PKCS12 import (wrong password?)
        public static var verificationFailed: Self { .init(.verificationFailed) }
    }

    public struct Identity {
        let secIdentity: SecIdentity

        public static func secIdentity(_ secIdentity: SecIdentity) -> Self {
            .init(secIdentity: secIdentity)
        }

        public static func p12(filename: String, password: String) throws -> Self {
            guard let secIdentity = try Self.loadP12(filename: filename, password: password) else { throw Error.invalidFormat }
            return .init(secIdentity: secIdentity)
        }

        private static func loadP12(filename: String, password: String) throws -> SecIdentity? {
            let data = try Data(contentsOf: URL(fileURLWithPath: filename))
            let options: [String: String] = [kSecImportExportPassphrase as String: password]
            var rawItems: CFArray?
            let result = SecPKCS12Import(data as CFData, options as CFDictionary, &rawItems)
            switch result {
            case errSecSuccess:
                break
            case errSecInteractionNotAllowed:
                throw Error.interactionNotAllowed
            case errSecPkcs12VerifyFailure:
                throw Error.verificationFailed
            default:
                throw Error.invalidFormat
            }
            let items = rawItems! as! [[String: Any]]
            let firstItem = items[0]
            return firstItem[kSecImportItemIdentity as String] as! SecIdentity?
        }
    }

    /// Struct defining an array of certificates
    public struct Certificates {
        let certificates: [SecCertificate]

        /// Create certificate array from already loaded SecCertificate array
        public static var none: Self { .init(certificates: []) }

        /// Create certificate array from already loaded SecCertificate array
        public static func certificates(_ secCertificates: [SecCertificate]) -> Self { .init(certificates: secCertificates) }

        /// Create certificate array from DER file
        public static func der(filename: String) throws -> Self {
            let certificateData = try Data(contentsOf: URL(fileURLWithPath: filename))
            guard let secCertificate = SecCertificateCreateWithData(nil, certificateData as CFData) else { throw Error.invalidFormat }
            return .init(certificates: [secCertificate])
        }
    }

    /// Initialize TSTLSOptions
    public init(_ options: NWProtocolTLS.Options?) {
        if let options {
            self.value = .some(options)
        } else {
            self.value = .none
        }
    }

    /// TSTLSOptions holding options
    public static func options(_ options: NWProtocolTLS.Options) -> Self {
        .init(value: .some(options))
    }

    public static func options(
        serverIdentity: Identity
    ) -> Self? {
        let options = NWProtocolTLS.Options()

        // server identity
        guard let secIdentity = sec_identity_create(serverIdentity.secIdentity) else { return nil }
        sec_protocol_options_set_local_identity(options.securityProtocolOptions, secIdentity)

        return .init(value: .some(options))
    }

    public static func options(
        clientIdentity: Identity,
        trustRoots: Certificates = .none,
        serverName: String? = nil
    ) -> Self? {
        let options = NWProtocolTLS.Options()

        // server identity
        guard let secIdentity = sec_identity_create(clientIdentity.secIdentity) else { return nil }
        sec_protocol_options_set_local_identity(options.securityProtocolOptions, secIdentity)
        if let serverName {
            sec_protocol_options_set_tls_server_name(options.securityProtocolOptions, serverName)
        }
        // sec_protocol_options_set
        sec_protocol_options_set_local_identity(options.securityProtocolOptions, secIdentity)

        // add verify block to control certificate verification
        if trustRoots.certificates.count > 0 {
            sec_protocol_options_set_verify_block(
                options.securityProtocolOptions,
                { _, sec_trust, sec_protocol_verify_complete in
                    let trust = sec_trust_copy_ref(sec_trust).takeRetainedValue()
                    SecTrustSetAnchorCertificates(trust, trustRoots.certificates as CFArray)
                    SecTrustEvaluateAsyncWithError(trust, Self.tlsDispatchQueue) { _, result, error in
                        if let error {
                            print("Trust failed: \(error.localizedDescription)")
                        }
                        sec_protocol_verify_complete(result)
                    }
                },
                Self.tlsDispatchQueue
            )
        }
        return .init(value: .some(options))
    }

    /// Empty TSTLSOptions
    public static var none: Self {
        .init(value: .none)
    }

    var options: NWProtocolTLS.Options? {
        if case .some(let options) = self.value { return options }
        return nil
    }

    /// Internal storage for TSTLSOptions. @unchecked Sendable while NWProtocolTLS.Options
    /// is not Sendable
    private enum Internal: @unchecked Sendable {
        case some(NWProtocolTLS.Options)
        case none
    }

    private let value: Internal
    private init(value: Internal) { self.value = value }

    /// Dispatch queue used by Network framework TLS to control certificate verification
    static let tlsDispatchQueue = DispatchQueue(label: "TSTLSConfiguration")
}
#endif
