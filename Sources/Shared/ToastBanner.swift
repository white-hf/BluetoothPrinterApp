import SwiftUI

struct ToastBanner: View {
    let message: ToastMessage

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
            Text(message.text)
                .font(.subheadline)
                .lineLimit(2)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(message.style.tintColor)
        .clipShape(Capsule())
        .shadow(radius: 4)
    }

    private var iconName: String {
        switch message.style {
        case .info: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.octagon.fill"
        }
    }
}
