import SwiftUI

struct AppRootView: View {
  @Environment(AppModel.self) private var model
  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    ZStack {
      MoyuTheme.warmBackground.ignoresSafeArea()

      switch model.loadingState {
      case .idle, .loading:
        ProgressView("正在准备 moyu")
          .tint(MoyuTheme.accent)
      case .failed(let message):
        ContentUnavailableView(
          "无法载入配置",
          systemImage: "exclamationmark.triangle",
          description: Text(message)
        )
      case .ready:
        if model.configuration.onboardingCompleted {
          MainTabs()
        } else {
          OnboardingView()
        }
      }

      if scenePhase != .active {
        PrivacyShield()
          .transition(.opacity)
          .zIndex(10)
      }
    }
    .animation(.easeOut(duration: 0.16), value: scenePhase)
  }
}

private struct MainTabs: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    @Bindable var model = model
    TabView {
      Tab("首页", systemImage: "clock") {
        NavigationStack { HomeView() }
      }
      Tab("存款", systemImage: "target") {
        NavigationStack { SavingsView() }
      }
    }
    .tint(MoyuTheme.accent)
    .moyuPersistentTabBar()
    .sheet(isPresented: $model.isShowingSettings) {
      NavigationStack { SettingsView() }
        .presentationBackground(.regularMaterial)
    }
  }
}

private struct PrivacyShield: View {
  var body: some View {
    ZStack {
      Rectangle().fill(.ultraThinMaterial)
      VStack(spacing: 12) {
        Image(systemName: "eye.slash.fill")
          .font(.system(size: 28, weight: .semibold))
          .foregroundStyle(MoyuTheme.accent)
        Text("moyu 已保护")
          .font(.headline)
      }
    }
    .ignoresSafeArea()
    .accessibilityLabel("隐私遮罩")
  }
}
