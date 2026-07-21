# moyu

`moyu` 是一款最低支持 iOS 26 的原生 SwiftUI 应用，用于显示实时收入、工作节点倒计时、法定节假日区间进度，以及可选的退休和存款目标。

完整产品规则见 [goal.md](goal.md)。

## 开发环境

- Xcode 26 或更高版本
- Swift 6
- XcodeGen 2.46 或更高版本
- ImageMagick（仅重新生成 App 图标时需要）

## 打开工程

```bash
xcodegen generate
open moyu.xcodeproj
```

首次运行前，在 Xcode 中为 `moyu` 和 `moyuWidgets` 两个 Target：

1. 选择同一个 Development Team。
2. 注册并启用 App Group：`group.com.ysq.moyu`。
3. 如果修改 Bundle ID，同时更新两个 entitlements、`AppModel` 和小组件中的 App Group 常量。

## 验证

无完整 Xcode 时，可验证纯 Swift 核心：

```bash
swift run MoyuVerify
```

安装 Xcode 26 后，运行共享 Scheme `moyu` 中的 `moyuTests`，并在 iOS 26 模拟器上检查 App 与四种小组件尺寸。

## 目录

- `App/`：iOS 应用、首次设置、首页、存款和设置界面
- `Widgets/`：主屏幕与锁屏倒计时小组件
- `Sources/MoyuCore/`：可测试的日历、收入、退休、存款、配置和节假日逻辑
- `Tests/MoyuCoreTests/`：Xcode 单元测试
- `Sources/MoyuVerify/`：无 XCTest 环境下的命令行回归验证
- `project.yml`：XcodeGen 工程定义

## Git

`.xcodeproj` 与 `project.yml` 一并纳入版本管理。修改工程定义后运行 `xcodegen generate`，并提交两者的变化。
