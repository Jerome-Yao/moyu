import SwiftUI

@main
struct MoyuApp: App {
  @State private var model = AppModel()

  var body: some Scene {
    WindowGroup {
      AppRootView()
        .environment(model)
        .task { await model.load() }
    }
  }
}
