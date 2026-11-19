import SwiftUI
import ForedeckCore

/// First run. Someone creates the boat, everyone else joins it, and then nobody
/// ever sees this screen again -- the code lives in the Keychain.
struct PairingView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var settings: SettingsStore
    @ObservedObject var boatStore: BoatStore

    @State private var boatName = ""
    @State private var joinCode = ""
    @State private var isScanning = false
    @State private var joinError: String?

    private var night: Bool { settings.nightMode }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                createPanel
                joinPanel
            }
            .padding(20)
        }
        .background(Deck.background(night: night).ignoresSafeArea())
        .sheet(isPresented: $isScanning) {
            QRScannerView { value in
                isScanning = false
                acceptScanned(value)
            }
            .ignoresSafeArea()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Foredeck")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(Deck.primaryText(night: night))
            Text("Hands-free crew intercom for docking and anchoring. Works over the boat's WiFi, or directly phone to phone when there isn't any.")
                .font(.system(size: 16))
                .foregroundStyle(Deck.secondaryText(night: night))
        }
    }

    private var createPanel: some View {
        DeckCard(night: night) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Set up your boat")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(Deck.primaryText(night: night))

                TextField("Boat name", text: $boatName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 18))
                    .padding(12)
                    .background(Deck.background(night: night), in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(Deck.primaryText(night: night))
                    .autocorrectionDisabled()

                Button("Create") {
                    let trimmed = boatName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    boatStore.createNewBoat(named: trimmed)
                }
                .buttonStyle(DeckButtonStyle(night: night, tint: Deck.accent(night: night).opacity(0.35)))
                .disabled(boatName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private var joinPanel: some View {
        DeckCard(night: night) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Or join a boat")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(Deck.primaryText(night: night))

                TextField("Boat name", text: $boatName)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(Deck.background(night: night), in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(Deck.primaryText(night: night))
                    .autocorrectionDisabled()

                TextField("Code", text: $joinCode)
                    .textFieldStyle(.plain)
                    .font(.system(size: 22, weight: .semibold, design: .monospaced))
                    .padding(12)
                    .background(Deck.background(night: night), in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(Deck.primaryText(night: night))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.characters)

                if let joinError {
                    Text(joinError)
                        .font(.system(size: 14))
                        .foregroundStyle(Deck.danger(night: night))
                }

                Button("Join") { join() }
                    .buttonStyle(DeckButtonStyle(night: night))

                Button {
                    isScanning = true
                } label: {
                    Label("Scan the QR code instead", systemImage: "qrcode.viewfinder")
                }
                .buttonStyle(DeckButtonStyle(night: night))
            }
        }
    }

    private func join() {
        let trimmedName = boatName.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalised = BoatKey.normalise(code: joinCode)
        guard !trimmedName.isEmpty else {
            joinError = "Enter the boat name exactly as the skipper set it."
            return
        }
        guard normalised.count >= 6 else {
            joinError = "That code looks too short."
            return
        }
        joinError = nil
        boatStore.pair(name: trimmedName, code: normalised)
    }

    private func acceptScanned(_ value: String) {
        guard let url = URL(string: value), let invitation = BoatInvitation(url: url) else {
            joinError = "That QR code isn't a Foredeck invitation."
            return
        }
        joinError = nil
        boatStore.pair(name: invitation.boatName, code: invitation.code)
    }
}
