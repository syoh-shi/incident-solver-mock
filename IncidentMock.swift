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

private enum ActionPage: Hashable {
    case actionA
    case actionB
}

private struct ActionPagerContext: Identifiable, Equatable {
    let id = UUID()
    let event: IncidentEvent
    var selection: ActionPage
}

struct IncidentMockView: View {
    @Environment(\.openURL) private var openURL

    @State private var pagerContext: ActionPagerContext? = nil

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
                                pagerContext = .init(event: event, selection: .actionA)
                            } onSwipeRight: {
                                pagerContext = .init(event: event, selection: .actionB)
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .padding(16)

            fullScreenPager
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: pagerContext != nil)
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
    private var fullScreenPager: some View {
        if let context = pagerContext {
            ActionPagerView(
                context: context,
                onClose: { pagerContext = nil },
                onOpenYahoo: { openURL(URL(string: "https://example.com/yahoo")!) },
                onOpenMaps: { openURL(URL(string: "https://example.com/maps")!) }
            )
            .transition(.opacity)
            .zIndex(1)
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

// MARK: - Action pager

private struct ActionPagerView: View {
    let context: ActionPagerContext
    let onClose: () -> Void
    let onOpenYahoo: () -> Void
    let onOpenMaps: () -> Void

    @State private var selection: ActionPage

    init(context: ActionPagerContext, onClose: @escaping () -> Void, onOpenYahoo: @escaping () -> Void, onOpenMaps: @escaping () -> Void) {
        self.context = context
        self.onClose = onClose
        self.onOpenYahoo = onOpenYahoo
        self.onOpenMaps = onOpenMaps
        _selection = State(initialValue: context.selection)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topTrailing) {
                Color(.systemBackground)
                    .ignoresSafeArea()

                pager(size: geo.size)

                closeButton
                    .padding(.top, 20)
                    .padding(.trailing, 20)
            }
        }
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(12)
                .background(
                    Circle()
                        .fill(Color(.systemGray6))
                )
        }
        .buttonStyle(.plain)
    }

    private func pager(size: CGSize) -> some View {
        TabView(selection: $selection) {
            ActionAScreen(event: context.event, onOpenYahoo: onOpenYahoo, onOpenMaps: onOpenMaps)
                .frame(width: size.height, height: size.width)
                .rotationEffect(.degrees(90))
                .tag(ActionPage.actionA)

            ActionBScreen(event: context.event)
                .frame(width: size.height, height: size.width)
                .rotationEffect(.degrees(90))
                .tag(ActionPage.actionB)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .rotationEffect(.degrees(-90))
        .frame(width: size.width, height: size.height)
    }
}

// MARK: - Action A screen

private struct ActionAScreen: View {
    let event: IncidentEvent
    let onOpenYahoo: () -> Void
    let onOpenMaps: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("代替手段を探す")
                        .font(.title2.weight(.semibold))
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

                infoCard
            }
            .padding(20)
        }
        .background(Color(.systemBackground))
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("スワイプで他の提案を見る")
                .font(.headline)
                .foregroundStyle(.primary)

            Text("上方向へのスワイプで、周辺で時間を使うプランに切り替えられます。")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Divider()

            Label("地図や乗換案内を開いてルートを確認", systemImage: "map")
                .font(.subheadline)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.systemGray6))
        )
    }
}

// MARK: - Action B screen

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
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("周辺で時間を使う")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text("\(event.lineName)（\(event.section)）の復旧を待っている間におすすめのスポットを表示します。")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                optionsGrid

                mockImpactMap(statusColor: event.status.accent)
                    .frame(height: 240)

                VStack(alignment: .leading, spacing: 8) {
                    Text("スワイプで切り替え")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text("上下にスワイプすると代替手段の提案と切り替えられます。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(20)
        }
        .background(Color(.systemBackground))
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
