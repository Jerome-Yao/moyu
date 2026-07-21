import SwiftUI

#if canImport(UIKit)
  import UIKit
  typealias MoyuPlatformColor = UIColor
#else
  import AppKit
  typealias MoyuPlatformColor = NSColor
#endif

enum MoyuTheme {
  static let accent = Color(red: 0.94, green: 0.31, blue: 0.12)
  static let warmBackground = Color(
    light: MoyuPlatformColor(red: 0.98, green: 0.96, blue: 0.91, alpha: 1),
    dark: MoyuPlatformColor(red: 0.055, green: 0.05, blue: 0.045, alpha: 1)
  )
  static let secondarySurface = Color(
    light: MoyuPlatformColor.black.withAlphaComponent(0.045),
    dark: MoyuPlatformColor.white.withAlphaComponent(0.07)
  )
}

extension Color {
  init(light: MoyuPlatformColor, dark: MoyuPlatformColor) {
    #if canImport(UIKit)
      self.init(
        uiColor: UIColor { traits in
          traits.userInterfaceStyle == .dark ? dark : light
        })
    #else
      self.init(
        nsColor: NSColor(name: nil) { appearance in
          appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        })
    #endif
  }
}

extension View {
  @ViewBuilder
  func moyuPersistentTabBar() -> some View {
    #if os(iOS)
      self.tabBarMinimizeBehavior(.never)
    #else
      self
    #endif
  }

  @ViewBuilder
  func moyuDecimalKeyboard() -> some View {
    #if os(iOS)
      self.keyboardType(.decimalPad)
    #else
      self
    #endif
  }

  @ViewBuilder
  func moyuInlineNavigationTitle() -> some View {
    #if os(iOS)
      self.navigationBarTitleDisplayMode(.inline)
    #else
      self
    #endif
  }
}

struct SectionLabel: View {
  let title: String
  let detail: String?

  init(_ title: String, detail: String? = nil) {
    self.title = title
    self.detail = detail
  }

  var body: some View {
    HStack(alignment: .firstTextBaseline) {
      Text(title)
        .font(.headline)
      Spacer()
      if let detail {
        Text(detail)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .accessibilityElement(children: .combine)
  }
}

struct SlimProgress: View {
  let value: Double

  var body: some View {
    GeometryReader { proxy in
      ZStack(alignment: .leading) {
        Capsule().fill(MoyuTheme.secondarySurface)
        Capsule()
          .fill(MoyuTheme.accent)
          .frame(width: proxy.size.width * min(max(value, 0), 1))
      }
    }
    .frame(height: 7)
    .animation(.smooth(duration: 0.5), value: value)
    .accessibilityValue(value.formatted(.percent.precision(.fractionLength(0))))
  }
}

enum MoyuFormat {
  static func money(_ value: Decimal, private isPrivate: Bool) -> String {
    guard !isPrivate else { return "••••" }
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencySymbol = "¥"
    formatter.currencyGroupingSeparator = ","
    formatter.minimumFractionDigits = 2
    formatter.maximumFractionDigits = 2
    formatter.locale = Locale(identifier: "zh_Hans_CN")
    return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "¥0.00"
  }
}
