import SwiftUI

struct InspectorView: View {
    @ObservedObject var model: InspectorModel
    let openSettings: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast

    private var surface: Color { colorScheme == .dark ? Color(red: 0.125, green: 0.129, blue: 0.125) : Color(red: 0.988, green: 0.988, blue: 0.984) }
    private var warningSurface: Color { colorScheme == .dark ? Color(red: 0.19, green: 0.13, blue: 0.14) : Color(red: 1, green: 0.945, blue: 0.94) }
    private var warningBorder: Color { Color.red.opacity(contrast == .increased ? 0.8 : 0.3) }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    if !model.isTrusted { permissionPane.padding(.horizontal, 22).padding(.top, 20) }
                    gestureBody(compact: geometry.size.width < 440)
                    if model.isTrusted { appContext.padding(.horizontal, 26) }
                    diagnostics
                }
                .frame(maxWidth: .infinity, minHeight: geometry.size.height, alignment: .top)
            }
            .background(surface)
        }
        .foregroundStyle(.primary)
    }

    private var permissionPane: some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.red)
                .padding(.top, 2)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text("Strafe can’t switch tabs")
                    .font(.system(size: 15, weight: .medium))
                    .accessibilityAddTraits(.isHeader)
                    .padding(.bottom, 5)
                Text("Strafe needs Accessibility access to send tab shortcuts.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 15)
                Button(action: openSettings) {
                    HStack(spacing: 10) {
                        Text("Open Accessibility Settings")
                        Image(systemName: "arrow.up.right").accessibilityHidden(true)
                    }
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 11).padding(.vertical, 8)
                    .background(surface, in: RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(warningBorder))
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the Accessibility pane in System Settings. Enable Strafe there.")
                Text(model.settingsError ? "Open System Settings → Privacy & Security → Accessibility." : "Turn on Strafe in the list.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 11)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .background(warningSurface, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(warningBorder))
    }

    private func gestureBody(compact: Bool) -> some View {
        let layout = compact ? AnyLayout(VStackLayout(alignment: .leading, spacing: 22)) : AnyLayout(HStackLayout(alignment: .center, spacing: 24))
        return layout {
            VStack(alignment: .leading, spacing: model.isTrusted ? 12 : 8) {
                Text(model.message.eyebrow.uppercased())
                    .font(.system(size: 10, weight: .medium)).tracking(1)
                    .foregroundStyle(.secondary)
                Text(model.message.title)
                    .font(.system(size: model.isTrusted ? 30 : 15, weight: .medium))
                    .tracking(model.isTrusted ? -1 : -0.2)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text(model.message.detail)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            InspectorTrackpad(state: model.debugState, echoes: model.contactEchoes,
                              enabled: model.isTrusted, preview: !model.isTrusted || model.isPreviewApp)
                .frame(maxWidth: .infinity)
                .frame(height: compact ? 165 : 146)
        }
        .padding(.horizontal, 26).padding(.vertical, model.isTrusted ? 32 : 24)
        .frame(minHeight: model.isTrusted && !compact ? 260 : nil)
    }

    private var appContext: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 8) {
                if let icon = model.appIcon {
                    Image(nsImage: icon).resizable().frame(width: 22, height: 22).accessibilityHidden(true)
                } else {
                    Image(systemName: "app").foregroundStyle(.secondary).accessibilityHidden(true)
                }
                Text(model.appName).font(.system(size: 12)).lineLimit(2)
                Spacer(minLength: 8)
                if let outcome = model.recentOutcome, outcome.routing.disposition == .sent {
                    HStack(spacing: 4) {
                        keycap("⌃")
                        if outcome.routing.event == .left { keycap("⇧") }
                        keycap("⇥")
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(outcome.routing.event == .left ? "Control Shift Tab sent" : "Control Tab sent")
                } else {
                    Text(model.contextLabel).font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }.padding(.vertical, 17)
        }
    }

    private func keycap(_ text: String) -> some View {
        Text(text).font(.system(size: 12)).foregroundStyle(.secondary)
            .frame(width: 23, height: 23)
            .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.primary.opacity(0.12)))
    }

    private var diagnostics: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(alignment: .top, spacing: 12) {
                Button {
                    model.detailsExpanded.toggle()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: model.detailsExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 9, weight: .medium)).accessibilityHidden(true)
                        Text("Details").font(.system(size: 11))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityValue(model.detailsExpanded ? "Expanded" : "Collapsed")
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 3) {
                    Text(model.lastOutcome == nil ? "No gesture yet" : "Last: \(model.lastOutcomeLabel)")
                    if !model.ageLabel.isEmpty { Text(model.ageLabel).monospacedDigit() }
                }
                .font(.system(size: 11))
                .multilineTextAlignment(.trailing)
                .accessibilityElement(children: .combine)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 26).padding(.vertical, 16)
            if model.detailsExpanded { detailRows.padding(.horizontal, 26).padding(.bottom, 20) }
        }
    }

    private var detailRows: some View {
        VStack(spacing: 0) {
            detail("Accessibility", model.isTrusted ? "Allowed" : "Required")
            detail("Current app", currentAppDetail)
            detail("Last gesture", lastGestureDetail)
        }
    }

    private var currentAppDetail: String {
        guard model.bundleID != nil else { return "No active app" }
        if model.isPreviewApp { return "Strafe · Preview only" }
        return "\(model.appName) · \(model.isSupportedApp ? "Supported" : "Not supported")"
    }

    private var lastGestureDetail: String {
        guard let outcome = model.lastOutcome else { return "No gesture yet" }
        let direction = outcome.routing.event == .left ? "Left" : "Right"
        switch outcome.routing.disposition {
        case .sent: return "\(direction) shortcut sent to \(outcome.appName)"
        case .preview: return "\(direction) preview · No shortcut sent"
        case .accessibilityRequired: return "\(direction) detected · Accessibility required"
        case .unsupportedApp: return "\(direction) detected · \(outcome.appName) isn’t supported"
        case .noFrontmostApp: return "\(direction) detected · No active app"
        }
    }

    private func detail(_ label: String, _ value: String) -> some View {
        VStack(spacing: 0) {
            Divider()
            HStack(alignment: .top, spacing: 16) {
                Text(label).foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text(value).multilineTextAlignment(.trailing).textSelection(.enabled)
            }
            .font(.system(size: 11)).fixedSize(horizontal: false, vertical: true).padding(.vertical, 9)
        }.accessibilityElement(children: .combine)
    }

}

private struct InspectorTrackpad: View {
    let state: GestureDebugState?
    let echoes: [ContactEcho]
    let enabled: Bool
    let preview: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.colorScheme) private var colorScheme

    private var contacts: [TouchDebugInfo] { state?.touches ?? [] }
    private var accent: Color { enabled ? .accentColor : .secondary }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ContactEchoSurface(echoes: echoes, dark: colorScheme == .dark,
                                   reducedMotion: reduceMotion, increasedContrast: contrast == .increased)
                    .background(colorScheme == .dark ? Color(red: 38/255, green: 41/255, blue: 34/255) : Color(red: 243/255, green: 244/255, blue: 239/255))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                VStack {
                    HStack {
                        Text("INPUT").tracking(0.6)
                        Spacer()
                        Text("\(contacts.count) contact\(contacts.count == 1 ? "" : "s")").monospacedDigit()
                    }
                    Spacer()
                    Text(state?.scrollSuppressed == true ? "GESTURE IGNORED" : preview ? "PREVIEW ONLY" : "REST + TAP").tracking(0.6)
                }
                .font(.system(size: 9)).foregroundStyle(.secondary).padding(11)
                if contacts.isEmpty {
                    Circle().strokeBorder(Color.secondary.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        .frame(width: 30, height: 30)
                }
                ForEach(contacts, id: \.id) { touch in
                    contact(touch)
                        .position(InspectorTrackpadGeometry.point(touch.position, in: geometry.size))
                }
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.primary.opacity(contrast == .increased ? 0.45 : 0.1))
                    .allowsHitTesting(false)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Trackpad input")
        .accessibilityValue(accessibilitySummary)
    }

    private func contact(_ touch: TouchDebugInfo) -> some View {
        let resting = touch.id == state?.restingId
        let tapping = touch.id == state?.tapCandidateId
        let moving = touch.movedBeyondScroll || touch.movedBeyondRest
        let color: Color = tapping && !moving ? accent : .secondary
        let label = touch.phase.isEnding ? "Released" : moving ? "Moving" : resting ? "Rest" : tapping ? "Tap" : "Touch"
        return ZStack {
            Circle().strokeBorder(color.opacity(0.7), style: StrokeStyle(lineWidth: 1, dash: touch.phase.isEnding ? [3, 3] : []))
                .frame(width: resting ? 28 : 24, height: resting ? 28 : 24)
            Circle().fill(resting ? Color.primary : color)
                .frame(width: touch.phase.isEnding ? 5 : 10, height: touch.phase.isEnding ? 5 : 10)
                .opacity(touch.phase.isEnding ? 0.4 : 1)
        }
        .overlay(alignment: .top) {
            Text(label).font(.system(size: 10)).foregroundStyle(.secondary)
                .fixedSize().offset(y: resting ? 33 : 29)
        }
    }

    private var accessibilitySummary: String {
        if contacts.isEmpty { return "No contacts" }
        return contacts.map { touch in
            let role = touch.id == state?.restingId ? "Resting finger" : touch.id == state?.tapCandidateId ? "Tapping finger" : "Finger"
            return "\(role), \(touch.phase.rawValue)\(touch.movedBeyondScroll ? ", moving" : "")"
        }.joined(separator: ". ")
    }
}
