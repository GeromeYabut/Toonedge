import SwiftUI

struct LibraryOrganizationSheet: View {
    @Environment(\.dismiss) private var dismiss
    let query: LibraryCollectionQuery
    let sourceOptions: [LibrarySourceOption]
    let selectSort: (LibrarySortChoice) -> Void
    let toggleSource: (String) -> Void
    let selectAllSources: () -> Void
    let reset: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Sort by", selection: Binding(
                        get: { LibrarySortChoice(query: query) },
                        set: { selectSort($0) }
                    )) {
                        ForEach(LibrarySortChoice.allCases) { choice in
                            Text(choice.title)
                                .tag(choice)
                                .accessibilityIdentifier("library.sort.\(choice.rawValue)")
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("library.organization.sortPicker")
                }
                Section("Sources") {
                    sourceRow(title: "All Sources", count: nil,
                        selected: query.selectedSourceDomains.isEmpty,
                        identifier: "library.sources.all", action: selectAllSources)
                    ForEach(sourceOptions) { option in
                        sourceRow(title: option.domain, count: option.titleCount,
                            selected: query.selectedSourceDomains.contains(option.domain),
                            identifier: "library.sources.\(option.domain)") {
                            toggleSource(option.domain)
                        }
                    }
                }
                Section {
                    Button(LibraryOrganizationLayout(query: query).resetTitle, action: reset)
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("library.sort.reset")
                }
            }
            .navigationTitle("Sort & filter")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("library.organization.done")
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func sourceRow(title: String, count: Int?, selected: Bool,
                           identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: ToonEdgeSpacing.small) {
                VStack(alignment: .leading, spacing: ToonEdgeSpacing.xsmall) {
                    Text(title)
                        .foregroundStyle(ToonEdgeColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let count {
                        Text("\(count) \(count == 1 ? "title" : "titles")")
                            .font(ToonEdgeTypography.caption)
                            .foregroundStyle(ToonEdgeColor.textSecondary)
                    }
                }
                Spacer(minLength: ToonEdgeSpacing.small)
                Image(systemName: "checkmark")
                    .foregroundStyle(ToonEdgeColor.accent)
                    .opacity(selected ? 1 : 0)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(count.map { "\(title), \($0) \($0 == 1 ? "title" : "titles")" } ?? title)
        .accessibilityValue(selected ? "Selected" : "Not selected")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier(identifier)
    }
}
