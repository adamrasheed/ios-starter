import SwiftUI

/// Placeholder for a tab that exists in the shell but is not built yet.
///
/// Worth having during a parallel build: the tab structure becomes reviewable before any
/// feature exists, and a stream that owns one tab can be wired in without the others being
/// finished. Delete it once every slot is filled.
struct ComingSoon: View {
    let title: String
    let detail: String

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.m) {
                Image(systemName: "hammer.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.textTertiary)
                Text(detail)
                    .font(AppFont.caption)
                    .foregroundStyle(.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xxl)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    ComingSoon(title: "Coming soon", detail: "Pick a track and this section is coming together.")
}
