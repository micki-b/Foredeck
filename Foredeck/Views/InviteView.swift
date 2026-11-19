import SwiftUI
import UIKit
import ForedeckCore

/// The pairing code, on demand, for as long as it is needed.
///
/// Presented as a sheet rather than drawn into a screen that navigation can
/// replace: crew arrive one at a time, often mid-manoeuvre, and the code has to
/// stay put until somebody dismisses it. It also fights the two things that
/// actually stop a phone camera reading a screen on deck -- the display dimming
/// on its idle timer, and low brightness in daylight.
struct InviteView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var boatStore: BoatStore
    @Environment(\.dismiss) private var dismiss

    @State private var previousBrightness: CGFloat?
    @State private var previousIdleTimerDisabled = false
    @State private var didCopy = false

    private var night: Bool { settings.nightMode }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let boat = boatStore.boat {
                    content(for: boat)
                } else {
                    Text("No boat is paired.")
                        .foregroundStyle(Deck.secondaryText(night: night))
                        .padding(40)
                }
            }
            .background(Deck.background(night: night).ignoresSafeArea())
            .navigationTitle("Invite crew")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .onAppear { holdTheScreenBright() }
        .onDisappear { restoreScreen() }
    }

    @ViewBuilder
    private func content(for boat: BoatStore.PairedBoat) -> some View {
        VStack(spacing: 20) {
            Text(boat.name)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(Deck.primaryText(night: night))

            if let url = BoatInvitation(boatName: boat.name, code: boat.code).url,
               let qr = QRCode.image(for: url.absoluteString) {
                qr.resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(maxWidth: 320)
                    .padding(16)
                    // Always white, never the night palette: a tinted QR code
                    // is a QR code that will not scan.
                    .background(.white, in: RoundedRectangle(cornerRadius: 16))
            }

            Text("Point the other phone's camera at this, using Scan on its pairing screen.")
                .font(.system(size: 15))
                .foregroundStyle(Deck.secondaryText(night: night))
                .multilineTextAlignment(.center)

            DeckCard(night: night) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Or type this code")
                        .font(.system(size: 14))
                        .foregroundStyle(Deck.secondaryText(night: night))

                    Text(BoatKey.formatted(code: boat.code))
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundStyle(Deck.primaryText(night: night))
                        .textSelection(.enabled)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)

                    Text("Boat name must match exactly: \(boat.name)")
                        .font(.system(size: 13))
                        .foregroundStyle(Deck.secondaryText(night: night))

                    Button {
                        UIPasteboard.general.string = BoatKey.formatted(code: boat.code)
                        didCopy = true
                    } label: {
                        Label(didCopy ? "Copied" : "Copy code", systemImage: didCopy ? "checkmark" : "doc.on.doc")
                    }
                    .buttonStyle(DeckButtonStyle(night: night))
                }
            }

            DeckCard(night: night) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Check code \(boat.key.fingerprint)")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(Deck.primaryText(night: night))
                    Text("Every crew member's Settings should show the same three characters. If one differs, that phone typed the code or the boat name wrongly and will not hear anyone.")
                        .font(.system(size: 13))
                        .foregroundStyle(Deck.secondaryText(night: night))
                }
            }

            Text("Anyone with this code and the boat name can join the intercom. Keep it to the crew.")
                .font(.system(size: 13))
                .foregroundStyle(Deck.secondaryText(night: night))
                .multilineTextAlignment(.center)
        }
        .padding(20)
    }

    /// A screen that sleeps or dims halfway through somebody lining up their
    /// camera is the whole complaint. Both are restored on the way out so we
    /// do not leave the phone burning battery at full brightness.
    private func holdTheScreenBright() {
        previousIdleTimerDisabled = UIApplication.shared.isIdleTimerDisabled
        UIApplication.shared.isIdleTimerDisabled = true

        let screen = UIScreen.main
        previousBrightness = screen.brightness
        if screen.brightness < 0.8 {
            screen.brightness = 0.8
        }
    }

    private func restoreScreen() {
        UIApplication.shared.isIdleTimerDisabled = previousIdleTimerDisabled
        if let previousBrightness {
            UIScreen.main.brightness = previousBrightness
        }
    }
}
