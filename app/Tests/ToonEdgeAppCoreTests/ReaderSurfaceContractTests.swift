import Foundation
import Testing
@testable import ToonEdgeAppCore
struct ReaderSurfaceContractTests {
    @Test func restoreRequiresCurrentIdentityAndNoUserInteraction() {
        var contract = ReaderSurfaceContract(sessionID: UUID(), pipelineID: UUID())
        let token = contract.restoreToken
        #expect(contract.acceptsRestore(token))
        contract.userDidInteract(); #expect(!contract.acceptsRestore(token))
        let replacement = ReaderSurfaceContract(sessionID: UUID(), pipelineID: UUID())
        #expect(!replacement.acceptsRestore(token))
    }
    @Test func pageRetryIdentityExpiresOnReuse() {
        var assignment = ReaderSurfacePageAssignment()
        let first = assignment.assign(sessionID: UUID(), pipelineID: UUID(), index: 1)
        #expect(assignment.matches(first))
        let second = assignment.assign(sessionID: UUID(), pipelineID: UUID(), index: 2)
        #expect(!assignment.matches(first)); #expect(assignment.matches(second))
        assignment.clear(); #expect(!assignment.matches(second))
    }
}
