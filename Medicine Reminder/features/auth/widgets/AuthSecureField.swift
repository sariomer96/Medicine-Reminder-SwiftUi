import SwiftUICore
import SwiftUI


public struct AuthSecureField: View {
    let title: String
    let placeholder: String
    @Binding var text: String

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.textPrimary)

            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text(placeholder)
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.78))
                        .padding(.horizontal, 16)
                }

                SecureField("", text: $text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundColor(AppTheme.textPrimary)
                    .accentColor(AppTheme.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
            }
                .background(AppTheme.surfaceMuted)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}
