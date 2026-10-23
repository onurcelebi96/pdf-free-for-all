import AppKit
import SwiftUI

/// Original blue-and-white launch signature, drawn with native text and shapes.
struct LaunchSignatureView: View {
    let dismiss: () -> Void
    private let blue = Color(red: 0.10, green: 0.27, blue: 0.73)

    private var handwriting: String {
        NSFont(name: "SnellRoundhand", size: 36) != nil ? "SnellRoundhand" : "BrushScriptMT"
    }

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor).opacity(0.98)
                .ignoresSafeArea()
            VStack(spacing: 22) {
                VStack(spacing: 0) {
                    VStack(spacing: 14) {
                        Image(systemName: "doc.richtext")
                            .font(.system(size: 26, weight: .light))
                            .accessibilityHidden(true)
                        Text("DESIGNED BY")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .tracking(4)
                        Text("Onur Celebi")
                            .font(.custom(handwriting, size: 49))
                            .padding(.bottom, 4)
                        Capsule().fill(.white.opacity(0.6))
                            .frame(width: 52, height: 1)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                    .background(blue.gradient)

                    Text("PDFs should be free,\nlike so many other things!")
                        .font(.custom(handwriting, size: 30))
                        .multilineTextAlignment(.center)
                        .lineSpacing(7)
                        .foregroundStyle(blue)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 30)
                        .background(.white)
                }
                .frame(width: 470)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(blue.opacity(0.12)))
                .shadow(color: blue.opacity(0.14), radius: 28, y: 12)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Designed by Onur Celebi. PDFs should be free, like so many other things!")

                Button("Continue", action: dismiss)
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(blue)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 9)
                    .background(blue.opacity(0.07), in: Capsule())
                    .keyboardShortcut(.defaultAction)
                    .help("Open your PDF workspace")
            }
        }
    }
}
