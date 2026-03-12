import Foundation

class RevisionRequest: ObservableObject {
    static let shared = RevisionRequest()

    @Published var filePath: String?

    func requestRevision(for path: String) {
        DispatchQueue.main.async {
            self.filePath = path
        }
    }
}
