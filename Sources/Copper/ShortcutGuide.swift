import SwiftUI

struct ShortcutGuideView: View {
    @Environment(\.dismiss) private var dismiss
    @Namespace private var glassNamespace

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Keyboard Shortcuts")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(20)

            Divider()

            ScrollView {
                GlassEffectContainer(spacing: 10) {
                    VStack(alignment: .leading, spacing: 22) {
                        ForEach(ShortcutGroup.allCases) { group in
                            let entries = ShortcutMap.all.filter { $0.group == group }
                            if !entries.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(group.rawValue.uppercased())
                                        .font(.system(size: 11, weight: .semibold))
                                        .tracking(1.15)
                                        .foregroundStyle(.secondary)

                                    VStack(alignment: .leading, spacing: 4) {
                                        ForEach(entries) { entry in
                                            HStack {
                                                Text(entry.title)
                                                    .font(.system(size: 13))
                                                Spacer()
                                                Text(entry.displayString)
                                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 3)
                                                    .glassEffect(.regular, in: Capsule())
                                                    .glassEffectID(entry.id, in: glassNamespace)
                                            }
                                            .padding(.vertical, 4)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
        }
        .frame(width: 440, height: 560)
        .background(.background)
    }
}
