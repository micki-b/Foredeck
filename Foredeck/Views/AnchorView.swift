import SwiftUI
import MapKit
import ForedeckCore

/// The shared picture. Every crew member sees the same anchor, the same circle
/// and the same numbers, and any of them can change them.
struct AnchorView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var settings: SettingsStore

    /// 300 m radius, so 600 m edge to edge. Wide enough to hold a normal swing
    /// circle plus the boats either side of you, tight enough that a drag of a
    /// boat length is visible rather than a pixel.
    private static let defaultSpanMeters: Double = 600
    private static let minimumSpanMeters: Double = 50
    private static let maximumSpanMeters: Double = 20_000

    @State private var camera: MapCameraPosition = .automatic
    @State private var visibleSpanMeters: Double = AnchorView.defaultSpanMeters
    @State private var visibleCenter: CLLocationCoordinate2D?
    @State private var hasAppliedDefaultScale = false

    private var night: Bool { settings.nightMode }
    private var state: AnchorState { model.anchorState }
    private var depthUnit: DepthUnit { settings.depthUnit }
    private var distanceUnit: DistanceUnit { settings.distanceUnit }

    private static let rodeRange: ClosedRange<Double> = 0...200
    private static let alarmRadiusRange: ClosedRange<Double> = 10...300

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                modePicker
                map.frame(height: 340).clipShape(RoundedRectangle(cornerRadius: Deck.corner))

                if let depth = model.signalK.depth {
                    instrumentRow(depth: depth)
                }

                if state.mode.value == .anchor {
                    anchorControls
                } else {
                    dockControls
                }
            }
            .padding(20)
        }
        .background(Deck.background(night: night).ignoresSafeArea())
        .alert("Anchor drag alarm", isPresented: alarmBinding) {
            Button("Acknowledge", role: .cancel) { model.alarm.acknowledge() }
        } message: {
            Text("\(distanceUnit.format(meters: model.alarm.lastDistance)) from the drop point.")
        }
    }

    private var alarmBinding: Binding<Bool> {
        Binding(get: { model.alarm.isFiring }, set: { if !$0 { model.alarm.acknowledge() } })
    }

    private var modePicker: some View {
        Picker("Mode", selection: Binding(
            get: { state.mode.value },
            set: { model.setMode($0) }
        )) {
            ForEach(CrewMode.allCases) { mode in
                Text(mode.label).tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Map

    private var map: some View {
        Map(position: $camera) {
            if let drop = state.anchorDrop.value {
                // The circle is the whole point of the picture: a distance
                // readout alone cannot tell sailing around the hook apart from
                // dragging, but a track inside or outside this can.
                MapCircle(center: drop.coordinate, radius: max(state.alarmRadiusMeters.value, 5))
                    .foregroundStyle(Deck.accent(night: night).opacity(0.12))
                    .stroke(Deck.accent(night: night), lineWidth: 2)

                Annotation("Anchor", coordinate: drop.coordinate) {
                    Image(systemName: "anchor")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Deck.primaryText(night: night))
                        .padding(6)
                        .background(Deck.surface(night: night), in: Circle())
                }
            }

            if let target = state.dockTarget.value {
                Annotation("Target", coordinate: target.coordinate) {
                    Image(systemName: "target")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Deck.warning(night: night))
                        .padding(6)
                        .background(Deck.surface(night: night), in: Circle())
                }
            }

            if model.location.track.count > 1 {
                MapPolyline(coordinates: model.location.track.map(\.coordinate))
                    .stroke(Deck.warning(night: night).opacity(0.8), lineWidth: 3)
            }

            if let here = model.effectivePosition {
                Annotation("Boat", coordinate: here.coordinate) {
                    Image(systemName: "location.north.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(Deck.accent(night: night))
                }
            }

            ForEach(model.crew) { member in
                if let position = member.position {
                    Annotation(member.displayName, coordinate: position.coordinate) {
                        Circle()
                            .fill(Deck.secondaryText(night: night))
                            .frame(width: 12, height: 12)
                    }
                }
            }
        }
        .mapStyle(.standard(elevation: .flat))
        .onMapCameraChange(frequency: .onEnd) { context in
            // Track where a pinch or drag left us, so the buttons zoom from
            // what is on screen rather than from wherever they last put it.
            visibleCenter = context.region.center
            // A degree of latitude is ~111 km everywhere; ample precision for
            // driving a zoom button.
            visibleSpanMeters = context.region.span.latitudeDelta * 111_000
        }
        .overlay(alignment: .topTrailing) { mapControls }
        .onAppear { applyDefaultScaleIfNeeded() }
        .onChange(of: state.anchorDrop.value) { _, _ in applyDefaultScaleIfNeeded() }
        .onChange(of: model.signalK.position) { _, _ in applyDefaultScaleIfNeeded() }
        .onChange(of: model.location.position) { _, _ in applyDefaultScaleIfNeeded() }
    }

    private var mapControls: some View {
        VStack(spacing: 10) {
            mapButton(systemName: "plus", label: "Zoom in") { zoom(by: 0.5) }
            mapButton(systemName: "minus", label: "Zoom out") { zoom(by: 2.0) }
            // Without this, panning away from the anchor is a one-way trip.
            mapButton(systemName: "scope", label: "Centre on anchor") { recentre() }
        }
        .padding(12)
    }

    private func mapButton(systemName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Deck.primaryText(night: night))
                .frame(width: Deck.minimumTarget, height: Deck.minimumTarget)
                .background(
                    Deck.surface(night: night).opacity(0.92),
                    in: RoundedRectangle(cornerRadius: 12)
                )
        }
        .accessibilityLabel(label)
    }

    /// What the map is about: the anchor if it is down, the dock target if one
    /// is set, otherwise the boat.
    private var focusPoint: GeoPoint? {
        state.anchorDrop.value ?? state.dockTarget.value ?? model.effectivePosition
    }

    private func zoom(by factor: Double) {
        guard let center = visibleCenter ?? focusPoint?.coordinate else { return }
        let span = min(max(visibleSpanMeters * factor, Self.minimumSpanMeters), Self.maximumSpanMeters)
        visibleSpanMeters = span
        setCamera(center: center, span: span)
    }

    private func recentre() {
        guard let center = focusPoint?.coordinate else { return }
        visibleCenter = center
        setCamera(center: center, span: visibleSpanMeters)
    }

    private func setCamera(center: CLLocationCoordinate2D, span: Double) {
        withAnimation(.easeInOut(duration: 0.2)) {
            camera = .region(
                MKCoordinateRegion(
                    center: center,
                    latitudinalMeters: span,
                    longitudinalMeters: span
                )
            )
        }
    }

    /// Frame the anchorage once, at a scale that means something.
    ///
    /// Gated on Signal K because that is when the fix comes from the boat's own
    /// GPS: stable enough that a fixed 300 m scale is genuinely useful. On a
    /// phone fix in a pocket, MapKit's automatic framing copes better with the
    /// wander. Only ever applied once, so it never fights a manual zoom.
    private func applyDefaultScaleIfNeeded() {
        guard settings.signalKEnabled, !hasAppliedDefaultScale else { return }
        guard let center = focusPoint?.coordinate else { return }
        hasAppliedDefaultScale = true
        visibleSpanMeters = Self.defaultSpanMeters
        visibleCenter = center
        setCamera(center: center, span: Self.defaultSpanMeters)
    }

    // MARK: - Instruments

    private func instrumentRow(depth: Double) -> some View {
        DeckCard(night: night) {
            HStack(spacing: 24) {
                readout(title: "Depth", value: depthUnit.format(meters: depth))
                if let wind = model.signalK.apparentWindSpeed {
                    readout(title: "AWS", value: String(format: "%.1f kn", wind * 1.94384))
                }
                if let sog = model.signalK.speedOverGround {
                    readout(title: "SOG", value: String(format: "%.1f kn", sog * 1.94384))
                }
            }
        }
    }

    private func readout(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Deck.secondaryText(night: night))
            Text(value)
                .font(Deck.readout(24))
                .foregroundStyle(Deck.primaryText(night: night))
        }
    }

    // MARK: - Anchor

    @ViewBuilder
    private var anchorControls: some View {
        DeckCard(night: night) {
            VStack(alignment: .leading, spacing: 16) {
                if let here = model.effectivePosition, let distance = state.dragDistance(from: here) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("From drop point")
                            .font(.system(size: 14))
                            .foregroundStyle(Deck.secondaryText(night: night))
                        Text(distanceUnit.format(meters: distance))
                            .font(Deck.readout(52))
                            .foregroundStyle(
                                distance > state.alarmRadiusMeters.value
                                    ? Deck.danger(night: night)
                                    : Deck.primaryText(night: night)
                            )
                    }
                }

                Text("Position from \(model.positionSource)")
                    .font(.system(size: 13))
                    .foregroundStyle(Deck.secondaryText(night: night))

                if state.anchorDrop.value == nil {
                    Button("Drop anchor here") {
                        guard let here = model.effectivePosition else { return }
                        model.dropAnchor(at: here)
                    }
                    .buttonStyle(DeckButtonStyle(night: night, tint: Deck.accent(night: night).opacity(0.35)))
                    .disabled(model.effectivePosition == nil)
                } else {
                    Button("Weigh anchor") {
                        model.weighAnchor()
                    }
                    .buttonStyle(DeckButtonStyle(night: night))
                }
            }
        }

        DeckCard(night: night) {
            VStack(alignment: .leading, spacing: 20) {
                stepper(title: "Rode out", meters: state.rodeMeters.value, range: Self.rodeRange) {
                    model.setRode($0)
                }

                stepper(title: "Alarm radius", meters: state.alarmRadiusMeters.value, range: Self.alarmRadiusRange) {
                    model.setAlarmRadius($0)
                }

                Button("Suggest from rode (\(distanceUnit.format(meters: model.suggestedAlarmRadius())))") {
                    model.setAlarmRadius(model.suggestedAlarmRadius())
                }
                .font(.system(size: 15))
                .foregroundStyle(Deck.accent(night: night))

                Toggle(isOn: Binding(
                    get: { state.alarmEnabled.value },
                    set: { model.setAlarmEnabled($0) }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Anchor alarm")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(Deck.primaryText(night: night))
                        Text("Wakes every phone on the boat, not just this one.")
                            .font(.system(size: 13))
                            .foregroundStyle(Deck.secondaryText(night: night))
                    }
                }
                .tint(Deck.accent(night: night))
                .disabled(state.anchorDrop.value == nil)
            }
        }
    }

    // MARK: - Dock

    @ViewBuilder
    private var dockControls: some View {
        DeckCard(night: night) {
            VStack(alignment: .leading, spacing: 16) {
                if let here = model.effectivePosition, let target = state.dockTarget.value {
                    let distance = Geo.distance(from: here, to: target)
                    let bearing = Geo.bearing(from: here, to: target)

                    HStack(alignment: .top, spacing: 32) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Distance")
                                .font(.system(size: 14))
                                .foregroundStyle(Deck.secondaryText(night: night))
                            Text(distanceUnit.format(meters: distance))
                                .font(Deck.readout(52))
                                .foregroundStyle(Deck.primaryText(night: night))
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Bearing")
                                .font(.system(size: 14))
                                .foregroundStyle(Deck.secondaryText(night: night))
                            Text(String(format: "%03.0f°", bearing))
                                .font(Deck.readout(52))
                                .foregroundStyle(Deck.primaryText(night: night))
                        }
                    }
                } else {
                    Text("Mark the berth, a piling, or wherever the bow needs to end up. Everyone sees the same mark and the same distance to it.")
                        .font(.system(size: 15))
                        .foregroundStyle(Deck.secondaryText(night: night))
                }

                if state.dockTarget.value == nil {
                    Button("Mark target here") {
                        guard let here = model.effectivePosition else { return }
                        model.setDockTarget(here)
                    }
                    .buttonStyle(DeckButtonStyle(night: night, tint: Deck.accent(night: night).opacity(0.35)))
                    .disabled(model.effectivePosition == nil)
                } else {
                    Button("Clear target") { model.setDockTarget(nil) }
                        .buttonStyle(DeckButtonStyle(night: night))
                }
            }
        }
    }

    // MARK: - Stepper

    private func stepper(
        title: String,
        meters: Double,
        range: ClosedRange<Double>,
        onChange: @escaping (Double) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(Deck.primaryText(night: night))
                Spacer()
                Text(distanceUnit.format(meters: meters))
                    .font(Deck.readout(22))
                    .foregroundStyle(Deck.primaryText(night: night))
            }
            HStack(spacing: 12) {
                Button {
                    onChange(distanceUnit.adjusted(meters: meters, bySteps: -1, clampedTo: range))
                } label: {
                    Image(systemName: "minus")
                        .frame(maxWidth: .infinity, minHeight: Deck.minimumTarget)
                }
                .buttonStyle(DeckButtonStyle(night: night))
                .accessibilityLabel("Decrease \(title)")

                Button {
                    onChange(distanceUnit.adjusted(meters: meters, bySteps: 1, clampedTo: range))
                } label: {
                    Image(systemName: "plus")
                        .frame(maxWidth: .infinity, minHeight: Deck.minimumTarget)
                }
                .buttonStyle(DeckButtonStyle(night: night))
                .accessibilityLabel("Increase \(title)")
            }
        }
    }
}
