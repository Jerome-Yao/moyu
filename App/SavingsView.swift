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
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(MoyuTheme.warmBackground.ignoresSafeArea())
    .navigationTitle("存款")
    .toolbar {
      if model.configuration.savings != nil {
        ToolbarItem(placement: .primaryAction) {
          Button {
            isEditing = true
          } label: {
            Image(systemName: "square.and.pencil")
          }
          .accessibilityLabel("编辑存款")
        }
      }
      SettingsToolbarButton()
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
    let realtimeBalance = snapshot?.realtimeBalance ?? plan.baselineAmount
    let accumulatedIncome = max(realtimeBalance - plan.baselineAmount, 0)

    return ScrollView {
      VStack(alignment: .leading, spacing: 38) {
        VStack(alignment: .leading, spacing: 10) {
          HStack {
            Text("实时存款")
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(.secondary)
            Spacer()
            Button {
              model.configuration.privacyModeEnabled.toggle()
              Task { try? await model.save() }
            } label: {
              Image(systemName: privateMode ? "eye.slash" : "eye")
                .font(.headline)
            }
            .buttonStyle(.glass)
            .accessibilityLabel(privateMode ? "显示金额" : "隐藏金额")
          }

          Text(
            MoyuFormat.money(realtimeBalance, private: privateMode)
          )
          .font(.system(size: 50, weight: .bold, design: .rounded))
          .monospacedDigit()
          .contentTransition(.numericText())
          .minimumScaleFactor(0.54)
          .lineLimit(1)
        }

        if let target = snapshot?.targetAmount, let progress = snapshot?.progress {
          targetProgress(
            snapshot: snapshot,
            target: target,
            progress: progress,
            privateMode: privateMode
          )
        } else {
          missingTarget
        }

        balanceComposition(
          plan: plan,
          accumulatedIncome: accumulatedIncome,
          privateMode: privateMode
        )
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 22)
      .padding(.top, 28)
      .padding(.bottom, 120)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private func targetProgress(
    snapshot: SavingsSnapshot?,
    target: Decimal,
    progress: Double,
    privateMode: Bool
  ) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      SectionLabel(
        "存款目标",
        detail: progress.formatted(.percent.precision(.fractionLength(1)))
      )
      SlimProgress(value: progress)
      HStack(alignment: .firstTextBaseline) {
        amountMetric("目标", value: target, privateMode: privateMode)
        Spacer()
        amountMetric(
          (snapshot?.remainingAmount ?? 0) > 0 ? "还差" : "已超出",
          value: (snapshot?.remainingAmount ?? 0) > 0
            ? snapshot?.remainingAmount ?? 0
            : snapshot?.exceededAmount ?? 0,
          privateMode: privateMode,
          alignment: .trailing
        )
      }
    }
  }

  private var missingTarget: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionLabel("存款目标", detail: "尚未设置")
      Text("设置一个目标金额后，这里会显示完成度和距离目标还差多少。")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      Button("设置存款目标") {
        isEditing = true
      }
      .buttonStyle(.glassProminent)
      .tint(MoyuTheme.accent)
    }
  }

  private func balanceComposition(
    plan: SavingsPlan,
    accumulatedIncome: Decimal,
    privateMode: Bool
  ) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      SectionLabel("余额构成")
      amountRow("期初存款", value: plan.baselineAmount, privateMode: privateMode)
      Divider()
      amountRow("工资累计", value: accumulatedIncome, privateMode: privateMode)
      Text("从 \(baselineDate(plan.baselineDay)) 00:00 起算")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }

  private func amountMetric(
    _ label: String,
    value: Decimal,
    privateMode: Bool,
    alignment: HorizontalAlignment = .leading
  ) -> some View {
    VStack(alignment: alignment, spacing: 4) {
      Text(label)
        .font(.caption)
        .foregroundStyle(.secondary)
      Text(MoyuFormat.money(value, private: privateMode))
        .font(.body.weight(.semibold))
        .monospacedDigit()
    }
  }

  private func amountRow(
    _ label: String,
    value: Decimal,
    privateMode: Bool
  ) -> some View {
    HStack(alignment: .firstTextBaseline) {
      Text(label)
        .foregroundStyle(.secondary)
      Spacer()
      Text(MoyuFormat.money(value, private: privateMode))
        .font(.body.weight(.semibold))
        .monospacedDigit()
    }
  }

  private func baselineDate(_ day: LocalDay) -> String {
    String(format: "%04d.%02d.%02d", day.year, day.month, day.day)
  }
}
