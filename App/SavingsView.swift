import MoyuCore
import SwiftUI

struct SavingsView: View {
  @Environment(AppModel.self) private var model
  @State private var isEditing = false

  var body: some View {
    Group {
      if let plan = model.configuration.savings {
        TimelineView(.periodic(from: .now, by: 1)) { context in
          savingsContent(plan: plan, now: context.date)
        }
      } else {
        emptyState
      }
    }
    .background(MoyuTheme.warmBackground)
    .navigationTitle("存款")
    .toolbar {
      SettingsToolbarButton()
      if model.configuration.savings != nil {
        ToolbarItem(placement: .secondaryAction) {
          Button("编辑") { isEditing = true }
        }
      }
    }
    .sheet(isPresented: $isEditing) {
      SavingsEditor()
        .presentationBackground(.regularMaterial)
    }
  }

  private var emptyState: some View {
    ContentUnavailableView {
      Label("开始记录存款", systemImage: "target")
    } description: {
      Text("存款只保存在本机，并随完整工作日工资和今日收入实时增长。")
    } actions: {
      Button("启用存款功能") { isEditing = true }
        .buttonStyle(.glassProminent)
        .tint(MoyuTheme.accent)
    }
  }

  private func savingsContent(plan: SavingsPlan, now: Date) -> some View {
    let snapshot = try? SavingsEngine(incomeEngine: model.incomeEngine()).snapshot(
      plan: plan, at: now)
    let privateMode = model.configuration.privacyModeEnabled

    return ScrollView {
      VStack(alignment: .leading, spacing: 36) {
        VStack(alignment: .leading, spacing: 10) {
          Text("实时存款")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
          Text(
            MoyuFormat.money(snapshot?.realtimeBalance ?? plan.baselineAmount, private: privateMode)
          )
          .font(.system(size: 48, weight: .bold, design: .rounded))
          .monospacedDigit()
          .contentTransition(.numericText())
          .minimumScaleFactor(0.64)
          .lineLimit(1)
        }

        if let target = snapshot?.targetAmount, let progress = snapshot?.progress {
          VStack(alignment: .leading, spacing: 14) {
            SectionLabel("存款目标", detail: progress.formatted(.percent.precision(.fractionLength(1))))
            SlimProgress(value: progress)
            HStack {
              VStack(alignment: .leading, spacing: 4) {
                Text("目标")
                  .font(.caption)
                  .foregroundStyle(.secondary)
                Text(MoyuFormat.money(target, private: privateMode))
                  .monospacedDigit()
              }
              Spacer()
              VStack(alignment: .trailing, spacing: 4) {
                Text((snapshot?.remainingAmount ?? 0) > 0 ? "还差" : "已超出")
                  .font(.caption)
                  .foregroundStyle(.secondary)
                Text(
                  MoyuFormat.money(
                    (snapshot?.remainingAmount ?? 0) > 0
                      ? snapshot?.remainingAmount ?? 0
                      : snapshot?.exceededAmount ?? 0,
                    private: privateMode
                  )
                )
                .monospacedDigit()
              }
            }
          }
        }
      }
      .padding(.horizontal, 22)
      .padding(.top, 30)
    }
  }
}
