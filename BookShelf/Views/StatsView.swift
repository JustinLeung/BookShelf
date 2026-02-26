import SwiftUI

struct StatsView: View {
    @Bindable var viewModel: BookshelfViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showGoalSetting = false

    @AppStorage("reminderEnabled") private var reminderEnabled = false
    @AppStorage("reminderHour") private var reminderHour = 20
    @AppStorage("reminderMinute") private var reminderMinute = 0
    @AppStorage("streakReminderEnabled") private var streakReminderEnabled = false

    private var reminderTime: Binding<Date> {
        Binding(
            get: {
                var components = DateComponents()
                components.hour = reminderHour
                components.minute = reminderMinute
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { newDate in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                reminderHour = components.hour ?? 20
                reminderMinute = components.minute ?? 0
                if reminderEnabled {
                    NotificationService.shared.scheduleDailyReminder(hour: reminderHour, minute: reminderMinute)
                }
            }
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    gardenSection
                    streaksSection
                    lifetimeSection
                    periodSection
                    goalsSection
                    remindersSection
                }
                .padding()
            }
            .navigationTitle("Reading Stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showGoalSetting) {
                GoalSettingView(viewModel: viewModel)
            }
        }
    }

    // MARK: - Garden

    private var gardenSection: some View {
        let finishedBooks = viewModel.books.filter { $0.readStatus == .read }
        return Group {
            if !finishedBooks.isEmpty {
                DetailSection(title: "Reading Garden") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("One plant for each book you've finished")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(finishedBooks) { book in
                                    gardenPlant(for: book)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
            }
        }
    }

    private func gardenPlant(for book: Book) -> some View {
        let symbol: String = {
            switch book.rating ?? 0 {
            case 5: return "tree.fill"
            case 4: return "leaf.fill"
            default: return "flower.fill"
            }
        }()

        let size: CGFloat = {
            let pages = book.pageCount ?? 200
            if pages >= 400 { return 36 }
            if pages >= 200 { return 28 }
            return 22
        }()

        let color: Color = {
            switch book.rating ?? 0 {
            case 5: return .green
            case 4: return .mint
            case 3: return .teal
            default: return .green.opacity(0.6)
            }
        }()

        return VStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: size))
                .foregroundStyle(color)
            Text(book.title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: 60)
        }
    }

    // MARK: - Streaks

    private var streaksSection: some View {
        let current = viewModel.currentStreak()
        let longest = viewModel.longestStreak()

        return DetailSection(title: "Streaks") {
            HStack(spacing: 32) {
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(current > 0 ? Color.orange : .secondary)
                        Text("\(current)")
                            .font(.title)
                            .fontWeight(.bold)
                    }
                    Text("Current")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 4) {
                    Text("\(longest)")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("Longest")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Lifetime

    private var lifetimeSection: some View {
        DetailSection(title: "Lifetime") {
            VStack(alignment: .leading, spacing: 8) {
                DetailRow(label: "Books Read", value: "\(viewModel.totalBooksRead)")
                DetailRow(label: "Total Pages", value: viewModel.totalPagesRead.formatted())

                if let avgRating = viewModel.averageRating {
                    DetailRow(label: "Avg Rating", value: String(format: "%.1f", avgRating) + " / 5")
                }

                if let avgDays = viewModel.averageDaysPerBook {
                    DetailRow(label: "Avg Days/Book", value: String(format: "%.0f", avgDays))
                }

                if let avgPages = viewModel.averagePagesPerDay {
                    DetailRow(label: "Avg Pages/Day", value: String(format: "%.0f", avgPages))
                }
            }
        }
    }

    // MARK: - Period

    private var periodSection: some View {
        DetailSection(title: "This Period") {
            VStack(alignment: .leading, spacing: 8) {
                let weekBooks = viewModel.booksFinished(in: viewModel.thisWeekInterval).count
                let weekPages = viewModel.pagesReadInPeriod(viewModel.thisWeekInterval)
                DetailRow(label: "This Week", value: "\(weekPages) pages · \(weekBooks) books")

                let monthBooks = viewModel.booksFinished(in: viewModel.thisMonthInterval).count
                let monthPages = viewModel.pagesReadInPeriod(viewModel.thisMonthInterval)
                DetailRow(label: "This Month", value: "\(monthPages) pages · \(monthBooks) books")

                let yearBooks = viewModel.booksFinished(in: viewModel.thisYearInterval).count
                let yearPages = viewModel.pagesReadInPeriod(viewModel.thisYearInterval)
                DetailRow(label: "This Year", value: "\(yearPages) pages · \(yearBooks) books")
            }
        }
    }

    // MARK: - Goals

    private var goalsSection: some View {
        DetailSection(title: "Goals") {
            VStack(alignment: .leading, spacing: 12) {
                if let daily = viewModel.dailyGoalProgress() {
                    goalProgressRow(label: "Daily", pagesRead: daily.pagesRead, goal: daily.goal)
                }

                if let weekly = viewModel.weeklyGoalProgress() {
                    goalProgressRow(label: "Weekly", pagesRead: weekly.pagesRead, goal: weekly.goal)
                }

                if viewModel.fetchReadingGoal() == nil {
                    Text("No goals set yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Button {
                    showGoalSetting = true
                } label: {
                    Text("Edit Goals")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.accentColor.opacity(0.12))
                        .foregroundStyle(Color.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    private func goalProgressRow(label: String, pagesRead: Int, goal: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text("\(pagesRead)/\(goal) pages")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray4))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(pagesRead >= goal ? Color.green : Color.accentColor)
                        .frame(width: geo.size.width * min(1.0, Double(pagesRead) / Double(max(goal, 1))))
                }
            }
            .frame(height: 8)
        }
    }

    // MARK: - Reminders

    private var remindersSection: some View {
        DetailSection(title: "Reminders") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Daily Reminder", isOn: $reminderEnabled)
                    .font(.subheadline)
                    .onChange(of: reminderEnabled) { _, newValue in
                        if newValue {
                            Task {
                                let granted = await NotificationService.shared.requestPermission()
                                if granted {
                                    NotificationService.shared.scheduleDailyReminder(hour: reminderHour, minute: reminderMinute)
                                } else {
                                    reminderEnabled = false
                                }
                            }
                        } else {
                            NotificationService.shared.cancelDailyReminder()
                        }
                    }

                if reminderEnabled {
                    DatePicker("Time", selection: reminderTime, displayedComponents: .hourAndMinute)
                        .font(.subheadline)
                }

                Toggle("Streak Protection", isOn: $streakReminderEnabled)
                    .font(.subheadline)
                    .onChange(of: streakReminderEnabled) { _, newValue in
                        if newValue {
                            Task {
                                let granted = await NotificationService.shared.requestPermission()
                                if granted {
                                    NotificationService.shared.scheduleStreakReminderIfNeeded(
                                        currentStreak: viewModel.currentStreak(),
                                        hasReadToday: viewModel.hasReadToday()
                                    )
                                } else {
                                    streakReminderEnabled = false
                                }
                            }
                        } else {
                            NotificationService.shared.cancelStreakReminder()
                        }
                    }

                Text("Get notified at 9 PM if your streak is at risk")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#if DEBUG
#Preview("Stats View") {
    StatsView(viewModel: BookshelfViewModel())
        .modelContainer(Book.previewContainer)
}
#endif
