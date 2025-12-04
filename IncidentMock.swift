import SwiftUI

enum IncidentStatus: String, CaseIterable, Identifiable {
    case stopped, delayed, caution
    var id: String { rawValue }

    var icon: String {
        switch self {
        case .stopped: return "×"
        case .delayed: return "!"
        case .caution: return "△"
        }
    }

    var accent: Color {
        switch self {
        case .stopped: return .red
        case .delayed: return .orange
        case .caution: return .yellow
        }
    }
}

struct IncidentEvent: Identifiable, Hashable {
    let id = UUID()
    let lineName: String
    let section: String
    let minutesAgo: Int
    let status: IncidentStatus

    var visualBarLength: CGFloat {
        let clamped = max(0, min(minutesAgo, 120))
        return CGFloat(clamped) / 120.0
    }
}

enum OverlayMode: Equatable, Hashable, Identifiable {
    case actionA(IncidentEvent)
    case actionB(IncidentEvent)

    var id: String {
        switch self {
        case .actionA(let event): return "actionA-\(event.id)"
        case .actionB(let event): return "actionB-\(event.id)"
        }
    }

    var event: IncidentEvent {
        switch self {
        case .actionA(let event), .actionB(let event): return event
        }
    }
}

struct IncidentMockView: View {
    @Environment(\.openURL) private var openURL

    @State private var overlay: OverlayMode? = nil

    private let locationLabel = "現在地：新宿駅（仮）"
    private let items: [IncidentEvent] = [
        .init(lineName: "山手線", section: "渋谷〜大崎", minutesAgo: 37, status: .delayed),
        .init(lineName: "中央線快速", section: "新宿〜中野", minutesAgo: 12, status: .caution),
        .init(lineName: "埼京線", section: "池袋〜新宿", minutesAgo: 58, status: .stopped)
    ]

    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                header

                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(items) { event in
                            SwipeableIncidentCard(event: event) {
                                overlay = .actionA(event)
                            } onSwipeRight: {
                                overlay = .actionB(event)
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .padding(16)

            FullScreenPager(mode: $overlay) { mode in
                overlay = mode
            } content: { mode in
                overlayContent(for: mode)
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: overlay != nil)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(locationLabel)
                .font(.title3)
                .foregroundStyle(.primary)

            Text("周辺の異常イベント")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 6)
    }

    @ViewBuilder
    private func overlayContent(for mode: OverlayMode) -> some View {
        switch mode {
        case .actionA(let event):
            ActionAScreen(
                event: event,
                onOpenYahoo: { openURL(URL(string: "https://example.com/yahoo")!) },
                onOpenMaps: { openURL(URL(string: "https://example.com/maps")!) }
            )

        case .actionB(let event):
            ActionBScreen(event: event)
        }
    }
}

// MARK: - Card

private struct SwipeableIncidentCard: View {
    let event: IncidentEvent
    let onSwipeLeft: () -> Void
    let onSwipeRight: () -> Void

    @State private var dragX: CGFloat = 0

    private let threshold: CGFloat = 84

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 6)

            content
                .padding(14)
        }
        .offset(x: dragX)
        .gesture(
            DragGesture(minimumDistance: 14)
                .onChanged { v in
                    let dx = v.translation.width
                    let dy = v.translation.height
                    guard abs(dx) > abs(dy) else { return }
                    dragX = dx * 0.9
                }
                .onEnded { v in
                    let dx = v.translation.width
                    let dy = v.translation.height
                    guard abs(dx) > abs(dy) else {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) { dragX = 0 }
                        return
                    }

                    if dx <= -threshold {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) { dragX = 0 }
                        onSwipeLeft()
                    } else if dx >= threshold {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) { dragX = 0 }
                        onSwipeRight()
                    } else {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) { dragX = 0 }
                    }
                }
        )
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                statusBadge

                VStack(alignment: .leading, spacing: 2) {
                    Text(event.lineName)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(event.section)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("今から\(event.minutesAgo)分前")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            barRow
        }
    }

    private var statusBadge: some View {
        ZStack {
            Circle()
                .fill(event.status.accent.opacity(0.16))

            Text(event.status.icon)
                .font(.headline)
                .foregroundStyle(event.status.accent)
                .padding(.bottom, 1)
        }
        .frame(width: 38, height: 38)
    }

    private var barRow: some View {
        GeometryReader { geo in
            let maxW = geo.size.width
            let w = max(12, maxW * event.visualBarLength)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(Color(.systemGray5))
                    .frame(height: 10)

                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(event.status.accent.opacity(0.55))
                    .frame(width: w, height: 10)
            }
        }
        .frame(height: 10)
    }
}

// MARK: - Overlay A

private struct ActionAScreen: View {
    let event: IncidentEvent
    let onOpenYahoo: () -> Void
    let onOpenMaps: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("代替手段を探す")
                        .font(.title3)
                        .foregroundStyle(.primary)

                    Text("\(event.lineName)（\(event.section)）に異常が発生しています")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 12) {
                    PrimaryButton(title: "Yahoo!乗換案内で開く", systemImage: "arrow.up.right.square") {
                        onOpenYahoo()
                    }

                    SecondaryButton(title: "Googleマップで開く", systemImage: "map") {
                        onOpenMaps()
                    }
                }
            }
            .padding(20)
        }
        .background(Color(.systemBackground))
        .overlay(alignment: .topLeading) {
            Text("Action A")
                .font(.caption)
                .padding(10)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(14)
        }
    }
}

// MARK: - Overlay B

private struct ActionBScreen: View {
    let event: IncidentEvent

    private let options: [(String, String)] = [
        ("カフェ", "cup.and.saucer"),
        ("コワーキング", "laptopcomputer"),
        ("Luup", "bicycle"),
        ("Uber/タクシー", "car")
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("周辺で時間を使う")
                        .font(.title3)
                        .foregroundStyle(.primary)

                    Text("\(event.lineName)（\(event.section)）")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                mockImpactMap(statusColor: event.status.accent)
                    .frame(height: 240)

                optionsGrid
            }
            .padding(20)
        }
        .background(Color(.systemBackground))
        .overlay(alignment: .topLeading) {
            Text("Action B")
                .font(.caption)
                .padding(10)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(14)
        }
    }

    private var optionsGrid: some View {
        let cols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        return LazyVGrid(columns: cols, spacing: 12) {
            ForEach(options, id: \.0) { title, symbol in
                OptionTile(title: title, systemImage: symbol)
            }
        }
    }

    private func mockImpactMap(statusColor: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.systemGray6))

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height

                Path { p in
                    p.move(to: CGPoint(x: w * 0.18, y: h * 0.72))
                    p.addLine(to: CGPoint(x: w * 0.52, y: h * 0.45))
                    p.addLine(to: CGPoint(x: w * 0.82, y: h * 0.36))
                }
                .stroke(Color(.systemGray3), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round, dash: [7, 6]))

                Path { p in
                    p.move(to: CGPoint(x: w * 0.34, y: h * 0.58))
                    p.addLine(to: CGPoint(x: w * 0.70, y: h * 0.40))
                }
                .stroke(statusColor, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))

                Circle()
                    .fill(Color(.systemBackground))
                    .overlay(Circle().stroke(Color(.systemGray3), lineWidth: 1))
                    .frame(width: 18, height: 18)
                    .position(x: w * 0.52, y: h * 0.45)

                Circle()
                    .fill(statusColor.opacity(0.20))
                    .frame(width: 42, height: 42)
                    .position(x: w * 0.52, y: h * 0.45)

                Text("現在地")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .position(x: w * 0.52, y: h * 0.66)
            }
            .padding(14)
        }
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 6)
    }
}

// MARK: - Full screen pager

private struct FullScreenPager<Content: View>: View {
    @Binding var mode: OverlayMode?
    var onPageChange: (OverlayMode) -> Void
    @ViewBuilder var content: (OverlayMode) -> Content

    var body: some View {
        Group {
            if let mode {
                FullscreenPagingContainer(mode: $mode, onPageChange: onPageChange, content: content)
                    .transition(.opacity)
            }
        }
    }
}

private struct FullscreenPagingContainer<Content: View>: View {
    @Binding var mode: OverlayMode?
    var onPageChange: (OverlayMode) -> Void
    @ViewBuilder var content: (OverlayMode) -> Content

    @State private var page: OverlayMode

    init(mode: Binding<OverlayMode?>, onPageChange: @escaping (OverlayMode) -> Void, content: @escaping (OverlayMode) -> Content) {
        _mode = mode
        self.onPageChange = onPageChange
        self.content = content
        _page = State(initialValue: mode.wrappedValue ?? .actionA(.init(lineName: "", section: "", minutesAgo: 0, status: .caution)))
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView(.vertical) {
                VStack(spacing: 0) {
                    content(.actionA(page.event))
                        .frame(maxHeight: .infinity)
                        .containerRelativeFrame(.vertical)
                        .id(OverlayMode.actionA(page.event))

                    content(.actionB(page.event))
                        .frame(maxHeight: .infinity)
                        .containerRelativeFrame(.vertical)
                        .id(OverlayMode.actionB(page.event))
                }
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $page)
            .background(Color(.systemBackground).ignoresSafeArea())
            .onChange(of: page) { newValue in
                mode = newValue
                onPageChange(newValue)
            }

            Button {
                mode = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
                    .padding(10)
            }
            .padding(.trailing, 14)
            .padding(.top, 18)
        }
        .onChange(of: mode) { newValue in
            if let newValue { page = newValue }
        }
    }
}

// MARK: - Small components

private struct OptionTile: View {
    let title: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color(.systemGray6))

                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(.primary)
            }
            .frame(width: 68, height: 68)

            Text(title)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 6)
    }
}

private struct PrimaryButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                Text(title)
                    .font(.headline)
                Spacer()
            }
            .foregroundStyle(.white)
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.accentColor)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct SecondaryButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                Text(title)
                    .font(.headline)
                Spacer()
            }
            .foregroundStyle(.primary)
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(.systemGray6))
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    IncidentMockView()
}
