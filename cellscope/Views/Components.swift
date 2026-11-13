import SwiftUI

enum Palette {
    static let ink = Color(red: 0.09, green: 0.18, blue: 0.16)
    static let green = Color(red: 0.08, green: 0.44, blue: 0.33)
    static let paper = Color(red: 0.96, green: 0.97, blue: 0.94)
    static let muted = Color(red: 0.39, green: 0.46, blue: 0.42)
    static let lime = Color(red: 0.78, green: 0.93, blue: 0.57)
}

struct SectionLabel: View {
    let number: String
    let title: String
    let detail: String
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number).font(.system(.caption, design: .monospaced, weight: .bold))
                .foregroundStyle(Palette.green).padding(7).background(Palette.green.opacity(0.09), in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline).foregroundStyle(Palette.ink)
                Text(detail).font(.caption).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}

struct EntryField: View {
    let title: String
    let unit: String
    @Binding var text: String
    var minimum: Double = 0
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.caption).foregroundStyle(Palette.muted)
            HStack {
                TextField(title, text: $text).keyboardType(.decimalPad)
                    .font(.system(.body, design: .monospaced, weight: .medium)).foregroundStyle(Palette.ink)
                    .accessibilityIdentifier(title)
                Text(unit).font(.caption).foregroundStyle(Palette.muted)
            }.padding(12).background(Palette.paper, in: RoundedRectangle(cornerRadius: 11))
            if CountInputs.positiveNumber(text).map({ $0 >= minimum }) != true {
                Text(minimum == 1 ? tr("请输入 ≥ 1 的数值") : tr("请输入大于 0 的数值")).font(.caption2).foregroundStyle(.red)
            }
        }
    }
}

struct PrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(.subheadline, weight: .semibold))
            .frame(maxWidth: .infinity).padding(.vertical, 15)
            .foregroundStyle(.white).background(Palette.green.opacity(configuration.isPressed ? 0.75 : 1), in: RoundedRectangle(cornerRadius: 14))
    }
}

extension View {
    func surface() -> some View {
        self.padding(18).background(.white, in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Palette.ink.opacity(0.055), lineWidth: 1))
    }
}

func formatted(_ value: Double, digits: Int = 2) -> String {
    if abs(value) >= 1_000_000 { return String(format: "%.2f × 10⁶", value / 1_000_000) }
    if abs(value) >= 10_000 { return String(format: "%.2f × 10⁴", value / 10_000) }
    return value.formatted(.number.precision(.fractionLength(0...digits)))
}
