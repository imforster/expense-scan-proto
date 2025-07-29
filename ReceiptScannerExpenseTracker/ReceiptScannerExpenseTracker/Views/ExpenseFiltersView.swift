import SwiftUI

struct ExpenseFiltersView: View {
    @ObservedObject var viewModel: ExpenseListViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingCustomDatePicker = false
    @State private var showingCustomAmountRange = false
    @State private var customStartDate = Date()
    @State private var customEndDate = Date()
    @State private var customMinAmount = ""
    @State private var customMaxAmount = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Category Filter
                    filterSection(title: "Category", icon: "tag.fill") {
                        categoryFilterContent
                    }
                    
                    // Date Range Filter
                    filterSection(title: "Date Range", icon: "calendar") {
                        dateRangeFilterContent
                    }
                    
                    // Amount Range Filter
                    filterSection(title: "Amount Range", icon: "dollarsign.circle") {
                        amountRangeFilterContent
                    }
                    
                    // Vendor Filter
                    filterSection(title: "Vendor", icon: "building.2") {
                        vendorFilterContent
                    }
                    
                    // Action Buttons
                    VStack(spacing: 12) {
                        PrimaryButton(title: "Apply Filters") {
                            dismiss()
                        }
                        
                        if viewModel.hasActiveFilters {
                            SecondaryButton(title: "Clear All Filters") {
                                viewModel.clearAllFilters()
                                dismiss()
                            }
                        }
                    }
                    .padding(.top)
                }
                .padding()
            }
            .navigationTitle("Filter Expenses")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingCustomDatePicker) {
            customDatePickerView
        }
        .sheet(isPresented: $showingCustomAmountRange) {
            customAmountRangeView
        }
    }
    
    private func filterSection<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(AppTheme.primaryColor)
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            content()
        }
        .padding()
        .background(AppTheme.Colors.cardBackground)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private var categoryFilterContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            // All Categories option
            CategoryFilterRow(
                name: "All Categories",
                color: .gray,
                icon: "circle.grid.3x3",
                isSelected: viewModel.selectedCategory == nil
            ) {
                viewModel.selectedCategory = nil
            }
            
            // Available categories
            ForEach(viewModel.getAvailableCategories(), id: \.id) { category in
                CategoryFilterRow(
                    name: category.safeName,
                    color: category.color,
                    icon: category.safeIcon,
                    isSelected: viewModel.selectedCategory == category
                ) {
                    viewModel.selectedCategory = category
                }
            }
        }
    }
    
    private var dateRangeFilterContent: some View {
        VStack(spacing: 8) {
            ForEach(ExpenseListViewModel.DateRange.allCases, id: \.self) { dateRange in
                DateRangeFilterRow(
                    dateRange: dateRange,
                    isSelected: viewModel.selectedDateRange == dateRange
                ) {
                    if dateRange == .custom {
                        showingCustomDatePicker = true
                    } else {
                        viewModel.selectedDateRange = dateRange
                        viewModel.customDateRange = nil
                    }
                }
            }
        }
    }
    
    private var amountRangeFilterContent: some View {
        VStack(spacing: 8) {
            ForEach(ExpenseListViewModel.AmountRange.allCases, id: \.self) { amountRange in
                AmountRangeFilterRow(
                    amountRange: amountRange,
                    isSelected: viewModel.selectedAmountRange == amountRange
                ) {
                    if amountRange == .custom {
                        showingCustomAmountRange = true
                    } else {
                        viewModel.selectedAmountRange = amountRange
                        viewModel.customAmountRange = nil
                    }
                }
            }
        }
    }
    
    private var vendorFilterContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            // All Vendors option
            VendorFilterRow(
                name: "All Vendors",
                isSelected: viewModel.selectedVendor == nil
            ) {
                viewModel.selectedVendor = nil
            }
            
            // Available vendors
            ForEach(viewModel.getUniqueVendors(), id: \.self) { vendor in
                VendorFilterRow(
                    name: vendor,
                    isSelected: viewModel.selectedVendor == vendor
                ) {
                    viewModel.selectedVendor = vendor
                }
            }
        }
    }
    
    private var customDatePickerView: some View {
        NavigationView {
            VStack(spacing: 20) {
                DatePicker(
                    "Start Date",
                    selection: $customStartDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(GraphicalDatePickerStyle())
                
                DatePicker(
                    "End Date",
                    selection: $customEndDate,
                    in: customStartDate...,
                    displayedComponents: [.date]
                )
                .datePickerStyle(GraphicalDatePickerStyle())
                
                PrimaryButton(title: "Apply Date Range") {
                    viewModel.selectedDateRange = .custom
                    viewModel.customDateRange = DateInterval(start: customStartDate, end: customEndDate)
                    showingCustomDatePicker = false
                }
            }
            .padding()
            .navigationTitle("Custom Date Range")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        showingCustomDatePicker = false
                    }
                }
            }
        }
    }
    
    private var customAmountRangeView: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Minimum Amount")
                        .font(.headline)
                    
                    AmountInputField(
                        placeholder: "0.00",
                        amount: $customMinAmount
                    )
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Maximum Amount")
                        .font(.headline)
                    
                    AmountInputField(
                        placeholder: "1000.00",
                        amount: $customMaxAmount
                    )
                }
                
                PrimaryButton(title: "Apply Amount Range") {
                    if let minAmount = Decimal(string: customMinAmount),
                       let maxAmount = Decimal(string: customMaxAmount),
                       minAmount <= maxAmount {
                        viewModel.selectedAmountRange = .custom
                        viewModel.customAmountRange = minAmount...maxAmount
                        showingCustomAmountRange = false
                    }
                }
                .disabled(customMinAmount.isEmpty || customMaxAmount.isEmpty)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Custom Amount Range")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        showingCustomAmountRange = false
                    }
                }
            }
        }
    }
}

// MARK: - Filter Row Components

struct CategoryFilterRow: View {
    let name: String
    let color: Color
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 20)
                
                Text(name)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(AppTheme.primaryColor)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
    }
}

struct DateRangeFilterRow: View {
    let dateRange: ExpenseListViewModel.DateRange
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: dateRange.systemImage)
                    .foregroundColor(AppTheme.primaryColor)
                    .frame(width: 20)
                
                Text(dateRange.rawValue)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(AppTheme.primaryColor)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
    }
}

struct AmountRangeFilterRow: View {
    let amountRange: ExpenseListViewModel.AmountRange
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: amountRange.systemImage)
                    .foregroundColor(AppTheme.primaryColor)
                    .frame(width: 20)
                
                Text(amountRange.rawValue)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(AppTheme.primaryColor)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
    }
}

struct VendorFilterRow: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "building.2")
                    .foregroundColor(AppTheme.primaryColor)
                    .frame(width: 20)
                
                Text(name)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(AppTheme.primaryColor)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
    }
}

#Preview {
    ExpenseFiltersView(viewModel: ExpenseListViewModel())
}
