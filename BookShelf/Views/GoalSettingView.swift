import SwiftUI

struct GoalSettingView: View {
    @Bindable var viewModel: BookshelfViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var dailyGoal: Int = 30
    @State private var weeklyGoal: Int = 200
    @State private var hasDailyGoal: Bool = false
    @State private var hasWeeklyGoal: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Daily Page Goal", isOn: $hasDailyGoal)

                    if hasDailyGoal {
                        Stepper("**\(dailyGoal)** pages/day", value: $dailyGoal, in: 10...100, step: 5)
                    }
                } footer: {
                    if hasDailyGoal {
                        Text("That's about \(dailyGoal / 2)–\(dailyGoal) minutes of reading")
                    }
                }

                Section {
                    Toggle("Weekly Page Goal", isOn: $hasWeeklyGoal)

                    if hasWeeklyGoal {
                        Stepper("**\(weeklyGoal)** pages/week", value: $weeklyGoal, in: 50...500, step: 25)
                    }
                } footer: {
                    if hasWeeklyGoal {
                        Text("That's about \(weeklyGoal / 7) pages per day")
                    }
                }

                Section {
                    Button("Clear All Goals", role: .destructive) {
                        viewModel.saveReadingGoal(daily: nil, weekly: nil)
                        dismiss()
                    }
                }
            }
            .navigationTitle("Reading Goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.saveReadingGoal(
                            daily: hasDailyGoal ? dailyGoal : nil,
                            weekly: hasWeeklyGoal ? weeklyGoal : nil
                        )
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                if let goal = viewModel.fetchReadingGoal() {
                    if let daily = goal.dailyPageGoal {
                        hasDailyGoal = true
                        dailyGoal = daily
                    }
                    if let weekly = goal.weeklyPageGoal {
                        hasWeeklyGoal = true
                        weeklyGoal = weekly
                    }
                }
            }
        }
    }
}

#if DEBUG
#Preview("Goal Setting") {
    GoalSettingView(viewModel: BookshelfViewModel())
        .modelContainer(Book.previewContainer)
}
#endif
