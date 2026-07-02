//
//  DeepLinkParser.swift
//  451Wallet
//
//  Created by User451 on 4/25/25.
//

import Foundation

func parse(url: URL) -> WalletAction? {
    guard url.scheme == "signator" else { return nil }

    let components = URLComponents(url: url, resolvingAgainstBaseURL: false)

    // signator://auth?challenge=...&service=...&serviceURL=...
    if url.host == "auth" {
        let items = components?.queryItems ?? []
        let challenge = items.first(where: { $0.name == "challenge" })?.value ?? ""
        let service = items.first(where: { $0.name == "service" })?.value ?? ""
        let serviceURL = items.first(where: { $0.name == "serviceURL" })?.value ?? ""
        guard !challenge.isEmpty, !service.isEmpty, !serviceURL.isEmpty else {
            return .unknown
        }
        return .signInToService(challenge: challenge, service: service, serviceURL: serviceURL)
    }

    // signator://sign?doc=...  (legacy)
    guard url.host == "sign",
          let docQuery = components?.queryItems?.first(where: { $0.name == "doc" })?.value else {
        return .unknown
    }

    let ids = docQuery.components(separatedBy: ",")
    if ids.count == 1 {
        return .signDocument(docId: ids[0])
    } else {
        return .signMultipleDocuments(docIds: ids)
    }
}
