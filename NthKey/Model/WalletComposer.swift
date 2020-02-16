//
//  WalletComposer.swift
//  WalletComposer
//
//  Created by Sjors Provoost on 16/02/2020.
//  Copyright © 2020 Purple Dunes. Distributed under the MIT software
//  license, see the accompanying file LICENSE.md

import Foundation
import LibWally

public struct WalletComposer : Codable {
    
    var announcements: [SignerAnnouncement]
    var policy: String?
    var policy_template: String?
    var sub_policies: [String: String]?

    public struct SignerAnnouncement: Codable {
        private var fingerprint: Data
        var name: String
        var fingerprintString: String {
            get { return fingerprint.hexString }
        }
        var can_decompile_miniscript: Bool?

        private enum CodingKeys : String, CodingKey {
            case fingerprintString = "fingerprint"
            case name
            case sub_policies
            case can_decompile_miniscript
        }
        
        init(fingerprint: Data, name: String, us: Bool) {
            self.fingerprint = fingerprint
            self.name = name
            if (us) {
                self.can_decompile_miniscript = false
            }
        }

        public init(from decoder:Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decode(String.self, forKey: .name)
            can_decompile_miniscript = try container.decode(Bool.self, forKey: .can_decompile_miniscript)
            let fingerprintString = try container.decode(String.self, forKey: .fingerprintString)

            if fingerprintString.count != 8 {
                throw DecodingError.dataCorruptedError(
                    forKey:.fingerprintString,
                    in: container,
                    debugDescription: """
                    Expected "\(fingerprintString)" to have 8 characters
                    """
                )
            }
    
            guard let value = Data(fingerprintString) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .fingerprintString,
                    in: container,
                    debugDescription: """
                    Failed to convert an instance of \(Data.self) from "\(fingerprintString)"
                    """
                )
            }
            
            if value.hexString != fingerprintString {
                  throw DecodingError.dataCorruptedError(
                      forKey:.fingerprintString,
                      in: container,
                      debugDescription: """
                      "\(fingerprintString)" is not hex
                      """
                  )
            }

            fingerprint = value
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(fingerprintString, forKey: .fingerprintString)
            try container.encode(name, forKey: .name)
            try container.encode(can_decompile_miniscript, forKey: .can_decompile_miniscript)
        }
    }

    public init?(us: Signer, signers: [Signer], threshold: Int? = nil) {
        self.announcements = signers.map { signer in
            return SignerAnnouncement(fingerprint: signer.fingerprint, name: us == signer ? "NthKey" : "", us: us == signer)
        }
        if let threshold = threshold {
            self.sub_policies = [:]
            self.policy = "thresh(\(threshold),\(signers.map { signer in "pk(\( signer.fingerprint.hexString ))" }.joined(separator:",") ))"
            self.policy_template = "thresh(\(threshold),\(signers.map { signer in "sub_policies(\( signer.fingerprint.hexString ))" }.joined(separator:",") ))"
            for signer in signers {
                self.sub_policies![signer.fingerprint.hexString] = "pk(\(signer.fingerprint.hexString))"
            }
        }
    }
}
