import SwiftUI

// MARK: - Animation Presets

/// 标准缓动动画（easeInOut, 0.3秒）
enum smoothAnimation {
    case standard
    case fast
    case slow

    var animation: Animation {
        switch self {
        case .standard: return .easeInOut(duration: 0.3)
        case .fast: return .easeInOut(duration: 0.2)
        case .slow: return .easeInOut(duration: 0.5)
        }
    }
}

/// 弹簧动画效果
enum springAnimation {
    case standard
    case bouncy
    case gentle

    var animation: Animation {
        switch self {
        case .standard: return .spring(response: 0.4, dampingFraction: 0.7)
        case .bouncy: return .spring(response: 0.3, dampingFraction: 0.6)
        case .gentle: return .spring(response: 0.5, dampingFraction: 0.8)
        }
    }
}

// MARK: - View Modifiers

extension View {
    /// 应用缓动动画
    func animatedSmooth() -> some View {
        self.animation(smoothAnimation.standard.animation, value: UUID())
    }

    /// 应用弹簧动画
    func animatedSpring() -> some View {
        self.animation(springAnimation.standard.animation, value: UUID())
    }

    /// 用于状态变化的动画
    func animated<T: Equatable>(_ value: T) -> some View {
        self.animation(.easeInOut(duration: 0.3), value: value)
    }
}

// MARK: - Animated Components

/// 带动画的卡片视图
struct AnimatedCardView<Content: View>: View {
    let content: Content
    @State private var isHovering = false
    @State private var isPressed = false

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(hoverBackgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(strokeColor, lineWidth: isHovering ? 2 : 1)
            )
            .scaleEffect(isPressed ? 0.98 : (isHovering ? 1.02 : 1.0))
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovering)
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isPressed)
            .onHover { hovering in
                isHovering = hovering
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        isPressed = true
                    }
                    .onEnded { _ in
                        isPressed = false
                    }
            )
    }

    private var hoverBackgroundColor: Color {
        isHovering ? Color.accentColor.opacity(0.08) : Color.secondary.opacity(0.05)
    }

    private var strokeColor: Color {
        isHovering ? Color.accentColor : Color.clear
    }
}

/// 带动画的 Toggle
struct AnimatedToggle: View {
    @Binding var isOn: Bool
    let title: String
    let description: String?

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .regular))
                if let description = description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .toggleStyle(.switch)
        .animation(.easeInOut(duration: 0.2), value: isOn)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isOn ? Color.accentColor.opacity(0.1) : Color.clear)
                .animation(.easeInOut(duration: 0.2), value: isOn)
        )
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
    }
}
