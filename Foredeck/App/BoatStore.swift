import Foundation
import Combine
import ForedeckCore

/// The paired boat: a name anyone can see and a code only the crew has.
@MainActor
final class BoatStore: ObservableObject {
    struct PairedBoat: Equatable {
        var name: String
        var code: String
        var key: BoatKey { BoatKey.derive(code: code, boatName: name) }
    }

    private enum Key {
        static let boatName = "foredeck.boatName"
        static let codeAccount = "boatCode"
    }

    @Published private(set) var boat: PairedBoat?
    /// Set when a boat is created here, so the crew screen can put the QR code
    /// up straight away. Cleared once that has happened.
    @Published private(set) var didJustCreateBoat = false

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let name = defaults.string(forKey: Key.boatName),
           let code = Keychain.get(Key.codeAccount) {
            boat = PairedBoat(name: name, code: code)
        }
    }

    func pair(name: String, code: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalised = BoatKey.normalise(code: code)
        guard !trimmed.isEmpty, !normalised.isEmpty else { return }

        defaults.set(trimmed, forKey: Key.boatName)
        Keychain.set(normalised, for: Key.codeAccount)
        boat = PairedBoat(name: trimmed, code: normalised)
    }

    @discardableResult
    func createNewBoat(named name: String) -> String {
        let code = BoatKey.randomCode()
        pair(name: name, code: code)
        didJustCreateBoat = true
        return code
    }

    func acknowledgeCreation() {
        didJustCreateBoat = false
    }

    func unpair() {
        defaults.removeObject(forKey: Key.boatName)
        Keychain.delete(Key.codeAccount)
        boat = nil
        didJustCreateBoat = false
    }
}
