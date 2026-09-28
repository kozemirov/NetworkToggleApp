import SwiftUI

struct AboutView: View {
    @EnvironmentObject var vm: NetworkToggleViewModel
    @State private var copyrightTapCount = 0
    @State private var lastTapTime: Date?
    @State private var feedback: String?

    private var appName: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? "Network Toggle"
    }
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }
    private var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)

            Text(appName)
                .font(.title2)
                .fontWeight(.semibold)

            Text("Version \(version) (\(build))")
                .font(.callout)
                .foregroundStyle(.secondary)

            Text("Shows the status of your network services and lets you turn them on and off from the menu bar and a Control Center")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 280)

            Text("© \(String(Calendar.current.component(.year, from: Date()))) Pavel Kozemirov")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .onTapGesture { handleCopyrightTap() }

            if let feedback {
                Text(feedback)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(28)
        .frame(width: 320)
        .fixedSize()
    }

    /// Hidden recovery switch: triple-tap the copyright line (within 1.5s) to force the helper to re-register.
    private func handleCopyrightTap() {
        let now = Date()
        if let last = lastTapTime, now.timeIntervalSince(last) > 1.5 {
            copyrightTapCount = 0
        }
        lastTapTime = now
        copyrightTapCount += 1
        guard copyrightTapCount >= 3 else { return }
        copyrightTapCount = 0

        vm.registerHelper()
        showFeedback(vm.errorMessage ?? "Helper re-registered")
    }

    private func showFeedback(_ text: String) {
        feedback = text
        Task {
            try? await Task.sleep(for: .seconds(2))
            feedback = nil
        }
    }
}
