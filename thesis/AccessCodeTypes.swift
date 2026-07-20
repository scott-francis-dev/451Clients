// AccessCodeTypes.swift
// Shared types for access code and deep-link persona flows.

import Foundation

/// One-time persona data delivered via deep link or QR code.
struct OneTimePersonaData: Codable {
    let name: String?
    let givenName: String?
    let address: Address?
    let email: String?
    let ssn: String?
    let documentID: String?
    let requestID: String?

    struct Address: Codable {
        let street: String?
        let city: String?
        let state: String?
        let zip: String?
        let country: String?
    }
}
