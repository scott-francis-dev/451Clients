//
//  WalletAction.swift
//  451Wallet
//
//  Created by User451 on 4/25/25.
//

enum WalletAction: Hashable, Identifiable {
    case signDocument(docId: String)
    case signMultipleDocuments(docIds: [String])
    case signPersona(personaId: String)
    case signContract(contractId: String)
    case verifyDocument(docId: String)
    case endorsePersona(targetPersonaId: String)
    case validateIdentity(requestId: String)
    case signInToService(challenge: String, service: String, serviceURL: String)
    case unknown

    var id: String {
        switch self {
        case .signDocument(let docId):
            return "sign:\(docId)"
        case .signMultipleDocuments(let docIds):
            return "multi:\(docIds.joined(separator: ","))"
        case .signPersona(let id):
            return "persona:\(id)"
        case .signContract(let id):
            return "contract:\(id)"
        case .verifyDocument(let id):
            return "verify:\(id)"
        case .endorsePersona(let id):
            return "endorse:\(id)"
        case .validateIdentity(let id):
            return "validate:\(id)"
        case .signInToService(let challenge, let service, _):
            return "service-signin:\(service):\(challenge)"
        case .unknown:
            return "unknown"
        }
    }
}
