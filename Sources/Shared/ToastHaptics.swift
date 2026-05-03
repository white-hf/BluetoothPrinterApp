//
//  ToastHaptics.swift
//  ScanSystem
//
//  Created by John Tang on 2025-09-22.
//

import SwiftUI
import UIKit

enum ToastStyle {
    case info
    case success
    case warning
    case error

    var feedbackType: UINotificationFeedbackGenerator.FeedbackType {
        switch self {
        case .info:
            return .success
        case .success:
            return .success
        case .warning:
            return .warning
        case .error:
            return .error
        }
    }

    var tintColor: Color {
        switch self {
        case .info:
            return .blue
        case .success:
            return .green
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }
}

enum ToastPosition {
    case top
    case center
    case bottom
}

struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let style: ToastStyle
    let position: ToastPosition
}

@MainActor
final class ToastHaptics: ObservableObject {
    static let shared = ToastHaptics()

    @Published var toast: ToastMessage?

    private let feedback = UINotificationFeedbackGenerator()

    func show(_ text: String, style: ToastStyle = .info, position: ToastPosition = .top) {
        let message = ToastMessage(text: text, style: style, position: position)
        toast = message
        feedback.prepare()
        feedback.notificationOccurred(style.feedbackType)
        Task { @MainActor in
            if #available(iOS 16.0, *) {
                try? await Task.sleep(for: .seconds(3.0)) // Changed to 3 seconds
            } else {
                try? await Task.sleep(nanoseconds: 3_000_000_000) // Changed to 3 seconds
            }
            if toast?.id == message.id {
                toast = nil
            }
        }
    }
}
