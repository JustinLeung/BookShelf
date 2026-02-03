import SwiftUI

struct BookDetailView: View {
    let book: Book
    @Bindable var viewModel: BookshelfViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Cover Image
                    bookCover
                        .frame(height: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)

                    // Title and Author
                    VStack(spacing: 8) {
                        Text(book.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)

                        Text(book.authorsDisplay)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // Read Status Toggle
                    HStack(spacing: 12) {
                        ForEach(ReadStatus.allCases, id: \.self) { status in
                            Button {
                                viewModel.setReadStatus(book, status: status)
                            } label: {
                                HStack {
                                    Image(systemName: status == .read ? "checkmark.circle.fill" : "bookmark.fill")
                                    Text(status.displayName)
                                }
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(book.readStatus == status ? Color.accentColor : Color(.systemGray5))
                                .foregroundStyle(book.readStatus == status ? .white : .primary)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                    .padding(.horizontal)

                    // Purchase Buttons
                    VStack(spacing: 12) {
                        if let amazonURL = book.amazonURL {
                            Link(destination: amazonURL) {
                                HStack {
                                    Image(systemName: "cart.fill")
                                    Text("Buy on Amazon")
                                }
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.orange)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }

                        if let audibleURL = book.audibleURL {
                            Link(destination: audibleURL) {
                                HStack {
                                    Image(systemName: "headphones")
                                    Text("Find on Audible")
                                }
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.purple)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                    .padding(.horizontal)

                    // Book Details
                    VStack(alignment: .leading, spacing: 16) {
                        if let description = book.bookDescription {
                            DetailSection(title: "Description") {
                                Text(description)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                            }
                        }

                        DetailSection(title: "Details") {
                            VStack(alignment: .leading, spacing: 8) {
                                DetailRow(label: "ISBN", value: book.isbn)

                                if let publisher = book.publisher {
                                    DetailRow(label: "Publisher", value: publisher)
                                }

                                if let publishDate = book.publishDate {
                                    DetailRow(label: "Published", value: publishDate)
                                }

                                if let pageCount = book.pageCount {
                                    DetailRow(label: "Pages", value: "\(pageCount)")
                                }

                                DetailRow(label: "Added", value: book.dateAdded.formatted(date: .abbreviated, time: .omitted))
                            }
                        }
                    }
                    .padding(.horizontal)

                    Spacer(minLength: 32)
                }
                .padding(.vertical)
            }
            .navigationTitle("Book Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .destructiveAction) {
                    Button(role: .destructive) {
                        viewModel.deleteBook(book)
                        dismiss()
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var bookCover: some View {
        if let data = book.coverImageData,
           let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.accentColor.opacity(0.1))

                Image(systemName: "book.closed.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(Color.accentColor)
            }
        }
    }
}

// MARK: - Helper Views

struct DetailSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }
}
