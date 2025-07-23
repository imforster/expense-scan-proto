import SwiftUI

struct ExpenseSortView: View {
    @ObservedObject var viewModel: ExpenseListViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sort Expenses")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Choose how you'd like to sort your expenses")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.white)
                
                Divider()
                
                // Sort Options
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(ExpenseListViewModel.SortOption.allCases, id: \.self) { sortOption in
                            SortOptionRow(
                                sortOption: sortOption,
                                isSelected: viewModel.sortOption == sortOption
                            ) {
                                viewModel.sortOption = sortOption
                                dismiss()
                            }
                            
                            if sortOption != ExpenseListViewModel.SortOption.allCases.last {
                                Divider()
                                    .padding(.leading, 60)
                            }
                        }
                    }
                }
                .background(Color.white)
            }
            .background(Color(.systemGray6))
            .navigationBarHidden(true)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

struct SortOptionRow: View {
    let sortOption: ExpenseListViewModel.SortOption
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: sortOption.systemImage)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? AppTheme.primaryColor : .gray)
                    .frame(width: 24, height: 24)
                
                // Title and description
                VStack(alignment: .leading, spacing: 2) {
                    Text(sortOption.rawValue)
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    Text(sortDescription(for: sortOption))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppTheme.primaryColor)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.white)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(sortOption.rawValue)
        .accessibilityHint(sortDescription(for: sortOption))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
    }
    
    private func sortDescription(for sortOption: ExpenseListViewModel.SortOption) -> String {
        switch sortOption {
        case .dateAscending:
            return "Show oldest expenses first"
        case .dateDescending:
            return "Show newest expenses first"
        case .amountAscending:
            return "Show smallest amounts first"
        case .amountDescending:
            return "Show largest amounts first"
        case .merchantAscending:
            return "Sort merchants alphabetically A-Z"
        case .merchantDescending:
            return "Sort merchants alphabetically Z-A"
        }
    }
}

#Preview {
    ExpenseSortView(viewModel: ExpenseListViewModel(context: PersistenceController.preview.container.viewContext))
}