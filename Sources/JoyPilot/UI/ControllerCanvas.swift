// SPDX-License-Identifier: GPL-3.0-only
import SwiftUI
import JoyPilotCore

struct ControllerCanvas: View {
    @Bindable var model: AppModel
    private struct Placement {
        let button: PadButton; let left: Bool; let y: CGFloat; let anchor: CGPoint
    }
    private let placements: [Placement] = [
        .init(button: .r, left: true, y: 62, anchor: CGPoint(x: -27, y: 73)),
        .init(button: .plus, left: true, y: 148, anchor: CGPoint(x: -48, y: 129)),
        .init(button: .y, left: true, y: 242, anchor: CGPoint(x: -43, y: 220)),
        .init(button: .stick, left: true, y: 350, anchor: CGPoint(x: 0, y: 347)),
        .init(button: .home, left: true, y: 447, anchor: CGPoint(x: -20, y: 444)),
        .init(button: .sl, left: true, y: 563, anchor: CGPoint(x: -53, y: 563)),
        .init(button: .zr, left: false, y: 62, anchor: CGPoint(x: 40, y: 63)),
        .init(button: .x, left: false, y: 167, anchor: CGPoint(x: 0, y: 176)),
        .init(button: .a, left: false, y: 266, anchor: CGPoint(x: 43, y: 220)),
        .init(button: .b, left: false, y: 364, anchor: CGPoint(x: 0, y: 264)),
        .init(button: .sr, left: false, y: 563, anchor: CGPoint(x: 53, y: 563))
    ]
    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let cardWidth = min(205.0, (width - 248) / 2)
            let center = width / 2
            ZStack {
                ForEach(placements, id: \.button) { p in
                    connector(p, width: width, cardWidth: cardWidth)
                }
                joyCon.position(x: center, y: 293)
                sideRail.position(x: center, y: 563)
                ForEach(placements, id: \.button) { p in
                    mappingCard(p.button)
                        .frame(width: cardWidth, height: 60)
                        .position(x: p.left ? cardWidth / 2 + 16 : width-cardWidth/2-16, y: p.y)
                }
                Text("正面").font(.system(size: 12)).foregroundStyle(PilotPalette.secondary)
                    .position(x: center, y: 518)
                Text("侧边").font(.system(size: 12)).foregroundStyle(PilotPalette.secondary)
                    .position(x: center, y: 607)
            }
        }
        .frame(height: 626)
    }
    private func connector(_ p: Placement, width: CGFloat, cardWidth: CGFloat) -> some View {
        let start = CGPoint(x: p.left ? cardWidth+16 : width-cardWidth-16, y: p.y)
        let end = CGPoint(x: width/2 + p.anchor.x, y: p.anchor.y)
        let selected = p.button == model.selectedButton
        return ZStack {
            Path { path in
                path.move(to: start)
                path.addCurve(to: end, control1: CGPoint(x: start.x + (p.left ? 40 : -40), y: start.y), control2: CGPoint(x: end.x + (p.left ? -40 : 40), y: end.y))
            }.stroke(selected ? PilotPalette.accent : Color.gray.opacity(0.38), style: StrokeStyle(lineWidth: selected ? 1.7 : 1.1, lineCap: .round))
            Circle().fill(selected ? PilotPalette.accent : Color.gray.opacity(0.65)).frame(width: 6, height: 6).overlay(Circle().stroke(.white, lineWidth: 1)).position(end)
        }.allowsHitTesting(false)
    }
    private func summary(_ button: PadButton) -> String {
        let command = model.settings.binding(for: button, scope: model.selectedScope, layer: model.editingLayer).primary
        if command.action == .voice { return model.settings.voice.provider == .doubao ? "豆包语音" : model.settings.voice.provider.rawValue }
        return command.applicationName.map { "打开 " + $0 } ?? command.shortcut?.label ?? command.action.title
    }
    private func detail(_ button: PadButton) -> String {
        if button == .stick { return "拨动移动 · 按下执行" }
        let action = model.settings.binding(for: button, scope: model.selectedScope, layer: model.editingLayer).primary.action
        if action == .voice { return model.settings.voice.gesture == .toggle ? "点按开始 / 结束" : "按住说话 · 松开结束" }
        if action == .leftClick { return "单击 · 按住可拖动" }
        if action.isContinuous { return "按住生效" }
        return model.editingLayer == .rHeld ? "R ＋ \(button.symbol)" : "单击执行"
    }
    private func mappingCard(_ button: PadButton) -> some View {
        let selected = button == model.selectedButton
        let active = model.activeButtons.contains(button)
        return Button { model.select(button) } label: {
            HStack(spacing: 10) {
                Text(button == .stick ? "◉" : button.symbol).font(.system(size: 14, weight: .semibold, design: .rounded))
                    .frame(width: button == .home ? 48 : 38, height: 30)
                    .background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 7))
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.gray.opacity(0.2)))
                VStack(alignment: .leading, spacing: 3) {
                    Text(summary(button)).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                    Text(detail(button)).font(.system(size: 12)).foregroundStyle(PilotPalette.secondary).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(active ? PilotPalette.accent.opacity(0.19) : selected ? PilotPalette.accent.opacity(0.085) : Color.white.opacity(0.86), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected || active ? PilotPalette.accent : Color.gray.opacity(0.22), lineWidth: selected ? 1.3 : 1))
            .shadow(color: .black.opacity(selected ? 0.06 : 0.035), radius: 5, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(button.title)：\(summary(button))")
        .help("点击设置 \(button.title) 的功能")
    }
    private var joyCon: some View {
        ZStack {
            // Rear ZR surface, distinct from the R shoulder.
            Button { model.select(.zr) } label: {
                Capsule().fill(Color(white: 0.16).gradient).frame(width: 80, height: 27).rotationEffect(.degrees(22))
            }.buttonStyle(.plain).offset(x: 38, y: -222).accessibilityLabel("选择 ZR 扳机")
            Button { model.select(.r) } label: {
                Capsule().fill(model.selectedButton == .r ? PilotPalette.accent.gradient : Color(white: 0.17).gradient).frame(width: 83, height: 20).rotationEffect(.degrees(7))
            }.buttonStyle(.plain).offset(x: -21, y: -215).accessibilityLabel("选择 R 肩键")
            RoundedRectangle(cornerRadius: 7).fill(Color(white: 0.18)).frame(width: 14, height: 416).offset(x: -86, y: 2)
            RightShell().fill(LinearGradient(colors: [Color(red: 1, green: 0.43, blue: 0.39), Color(red: 0.95, green: 0.28, blue: 0.25)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(RightShell().stroke(.white.opacity(0.45), lineWidth: 2))
                .shadow(color: Color(red: 0.35, green: 0.17, blue: 0.15).opacity(0.24), radius: 13, x: 2, y: 12)
            physical(.plus, text: "+", x: -48, y: -164, diameter: 27, plus: true)
            physical(.x, text: "X", x: 0, y: -117)
            physical(.y, text: "Y", x: -43, y: -73)
            physical(.a, text: "A", x: 43, y: -73)
            physical(.b, text: "B", x: 0, y: -29)
            Button { model.select(.stick) } label: {
                ZStack {
                    Circle().fill(Color(white: 0.12)).frame(width: 74, height: 74)
                    Circle().fill(LinearGradient(colors: [Color(white: 0.29), Color(white: 0.12)], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 57, height: 57)
                        .overlay(Circle().stroke(.black.opacity(0.5), lineWidth: 2))
                        .offset(x: model.displayStick.x*4, y: -model.displayStick.y*4)
                }
                .overlay(Circle().stroke(model.activeButtons.contains(.stick) ? PilotPalette.accent : Color.clear, lineWidth: 3))
                .shadow(color: .black.opacity(0.25), radius: 3, y: 3)
            }.buttonStyle(.plain).offset(x: 0, y: 54).accessibilityLabel("选择摇杆按下功能")
            Button { model.select(.home) } label: {
                Image(systemName: "house").font(.system(size: 18, weight: .semibold)).foregroundStyle(.white)
                    .frame(width: 39, height: 39).background(Color(white: 0.17), in: Circle())
                    .overlay(Circle().stroke(model.activeButtons.contains(.home) ? PilotPalette.accent : Color.white.opacity(0.3), lineWidth: 2))
            }.buttonStyle(.plain).offset(x: -20, y: 151).accessibilityLabel("选择 Home 键")
        }
        .frame(width: 172, height: 440)
    }
    private func physical(_ button: PadButton, text: String, x: CGFloat, y: CGFloat, diameter: CGFloat = 39, plus: Bool = false) -> some View {
        Button { model.select(button) } label: {
            Text(text).font(.system(size: plus ? 33 : 23, weight: plus ? .bold : .regular, design: .rounded)).foregroundStyle(plus ? Color(white: 0.12) : .white)
                .frame(width: diameter, height: diameter)
                .background(plus ? Color.clear : Color(white: 0.16), in: Circle())
                .overlay(Circle().stroke(model.activeButtons.contains(button) ? PilotPalette.accent : Color.clear, lineWidth: 3))
                .shadow(color: .black.opacity(plus ? 0 : 0.3), radius: 2, y: 3)
        }.buttonStyle(.plain).offset(x: x, y: y).accessibilityLabel("选择 \(button.title)")
    }
    private var sideRail: some View {
        ZStack {
            Capsule().fill(Color(red: 1, green: 0.39, blue: 0.34)).frame(width: 228, height: 49)
            Capsule().fill(Color(white: 0.16).gradient).frame(width: 210, height: 34)
            HStack(spacing: 62) {
                sideButton(.sl)
                sideButton(.sr)
            }
            HStack(spacing: 7) { ForEach(0..<4) { n in RoundedRectangle(cornerRadius: 1).fill(n == 0 && model.connected ? Color.green : Color(white: 0.32)).frame(width: 4, height: 7) } }
        }
    }
    private func sideButton(_ button: PadButton) -> some View {
        Button { model.select(button) } label: {
            Text(button.symbol).font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
                .frame(width: 45, height: 23).background(model.activeButtons.contains(button) ? PilotPalette.accent : Color(white: 0.28), in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.3)))
        }.buttonStyle(.plain).accessibilityLabel("选择侧边 \(button.title)")
    }
}
private struct RightShell: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: 9, y: 7))
        p.addQuadCurve(to: CGPoint(x: w-4, y: 86), control: CGPoint(x: w-4, y: -5))
        p.addLine(to: CGPoint(x: w-4, y: h-88))
        p.addQuadCurve(to: CGPoint(x: 9, y: h-4), control: CGPoint(x: w-4, y: h))
        p.addQuadCurve(to: CGPoint(x: 3, y: h-12), control: CGPoint(x: 3, y: h-4))
        p.addLine(to: CGPoint(x: 3, y: 14))
        p.addQuadCurve(to: CGPoint(x: 9, y: 7), control: CGPoint(x: 3, y: 7))
        p.closeSubpath(); return p
    }
}
