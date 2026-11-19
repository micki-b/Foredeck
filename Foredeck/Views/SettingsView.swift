import SwiftUI
import UIKit
import ForedeckCore

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var settings: SettingsStore
    @ObservedObject var boatStore: BoatStore

    @State private var confirmUnpair = false

    var body: some View {
        Form {
            Section("You") {
                TextField("Name", text: $settings.displayName)
                Picker("Station", selection: $settings.role) {
                    ForEach(CrewRole.allCases) { role in
                        Text(role.label).tag(role)
                    }
                }
            }

            Section {
                Picker("Talk mode", selection: $settings.talkMode) {
                    ForEach(TalkMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                VStack(alignment: .leading) {
                    Text("Mic sensitivity")
                    Slider(value: $settings.vadSensitivity, in: 0...1)
                    Text("Lower it when the wind is up and the mic keeps opening on its own; raise it if quiet speech is being cut off.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Voice")
            } footer: {
                Text("A headset or AirPods will beat a phone at arm's length in any real wind. Nothing in software fixes a microphone in a gale.")
            }

            Section("Audio quality") {
                Picker("Codec", selection: $settings.codec) {
                    Text("mu-law (recommended)").tag(CodecID.pcmuLaw)
                    Text("Raw PCM (double bandwidth)").tag(CodecID.pcm16)
                }
                Text("Takes effect the next time you start a session.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Boat") {
                LabeledContent("Name", value: boatStore.boat?.name ?? "Not paired")
                LabeledContent("Length") {
                    Stepper("\(Int(settings.boatLengthMeters)) m", value: $settings.boatLengthMeters, in: 4...40, step: 1)
                }
                Text("Used to suggest an anchor alarm radius that allows for how far the boat can lie from the anchor.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Use Signal K", isOn: $settings.signalKEnabled)
                if settings.signalKEnabled {
                    TextField("Host", text: $settings.signalKHost)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    LabeledContent("Port", value: String(settings.signalKPort))
                    LabeledContent("Status", value: model.signalK.isConnected ? "Connected" : "Not connected")
                }
            } header: {
                Text("Boat instruments")
            } footer: {
                Text("If the boat's Signal K server is reachable, Foredeck uses its GPS for the anchor position — it is mounted better than a phone in a pocket — and shows live depth.")
            }

            Section {
                Picker("Depth", selection: $settings.depthUnit) {
                    ForEach(DepthUnit.allCases) { unit in
                        Text(unit.label).tag(unit)
                    }
                }
                Picker("Distance", selection: $settings.distanceUnit) {
                    ForEach(DistanceUnit.allCases) { unit in
                        Text(unit.label).tag(unit)
                    }
                }
            } header: {
                Text("Units")
            } footer: {
                Text("Display only. Everything is stored and shared between crew in metres, so changing this never moves the anchor or the alarm radius.")
            }

            Section {
                Toggle("Night mode", isOn: $settings.nightMode)
                AppIconPicker()
            } header: {
                Text("Display")
            } footer: {
                Text("The night icon is red on black, so finding the app on the home screen during a night watch does not cost you your dark adaptation.")
            }

            Section {
                Button("Unpair this boat", role: .destructive) { confirmUnpair = true }
            } footer: {
                Text("You will need the boat name and code again to rejoin.")
            }
        }
        .confirmationDialog("Unpair this boat?", isPresented: $confirmUnpair, titleVisibility: .visible) {
            Button("Unpair", role: .destructive) {
                model.endSession()
                boatStore.unpair()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

/// Choice of home screen icon.
///
/// iOS owns this state and keeps it across launches and app updates, so it is
/// read back from `UIApplication` rather than mirrored into `SettingsStore`,
/// where the two could drift apart.
@MainActor
private struct AppIconPicker: View {
    private enum Choice: CaseIterable, Identifiable {
        case standard, night

        var id: Self { self }

        /// `nil` is how UIKit names the primary icon. The night name must match
        /// both the asset catalog and ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES.
        var alternateIconName: String? {
            switch self {
            case .standard: return nil
            case .night: return "AppIcon-Night"
            }
        }

        var label: String {
            switch self {
            case .standard: return "Standard"
            case .night: return "Night"
            }
        }

        /// A plain image copy of each icon. The icons themselves cannot be
        /// loaded with `Image(_:)` once actool has compiled them.
        var previewImage: String {
            switch self {
            case .standard: return "AppIconPreview"
            case .night: return "AppIconPreview-Night"
            }
        }
    }

    // Read in onAppear rather than as the initial value: a property default is
    // evaluated outside the main actor, and UIApplication is main-actor only.
    @State private var selection: Choice = .standard
    @State private var failure: String?

    private static let iconSize: CGFloat = 60
    /// The corner radius iOS uses for a 60 pt home screen icon.
    private static let iconCorner: CGFloat = 13.5

    var body: some View {
        HStack(spacing: 32) {
            ForEach(Choice.allCases) { choice in
                Button {
                    select(choice)
                } label: {
                    VStack(spacing: 8) {
                        Image(choice.previewImage)
                            .resizable()
                            .frame(width: Self.iconSize, height: Self.iconSize)
                            .clipShape(RoundedRectangle(cornerRadius: Self.iconCorner, style: .continuous))
                            .padding(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: Self.iconCorner + 4, style: .continuous)
                                    .stroke(selection == choice ? Color.accentColor : .clear, lineWidth: 3)
                            )
                        Text(choice.label)
                            .font(.caption)
                    }
                    // The whole column is the target, not just the image.
                    .frame(minWidth: Deck.minimumTarget, minHeight: Deck.minimumTarget)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(choice.label) app icon")
                .accessibilityAddTraits(selection == choice ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .onAppear {
            selection = UIApplication.shared.alternateIconName == Choice.night.alternateIconName ? .night : .standard
        }
        .alert("Could not change the icon", isPresented: Binding(
            get: { failure != nil },
            set: { if !$0 { failure = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(failure ?? "")
        }
    }

    private func select(_ choice: Choice) {
        guard choice != selection, UIApplication.shared.supportsAlternateIcons else { return }
        let previous = selection
        selection = choice
        Task {
            do {
                // iOS shows its own "You have changed the icon" alert here;
                // there is no public way to suppress it.
                try await UIApplication.shared.setAlternateIconName(choice.alternateIconName)
            } catch {
                selection = previous
                failure = error.localizedDescription
            }
        }
    }
}
