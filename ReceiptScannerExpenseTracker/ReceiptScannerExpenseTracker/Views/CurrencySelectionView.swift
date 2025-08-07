import SwiftUI

struct CurrencySelectionView: View {
    @Binding var selectedCurrencyCode: String
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var filteredCurrencies: [CurrencyInfo] = []
    private let currencyService = CurrencyService.shared
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                searchBarView
                currencyListView
            }.navigationTitle("Select Currency").navigationBarTitleDisplayMode(.inline).toolbar {
                ToolbarItem(placement: .navigationBarTrailing) { Button("Cancel") { dismiss() } }
            }.onAppear { updateFilteredCurrencies() }.onChange(of: searchText) { _ in updateFilteredCurrencies() }
        }
    }
    private var searchBarView: some View {
        CurrencySearchBar(text: $searchText, placeholder: "Search currencies").padding(.horizontal).padding(.top, 8)
    }
    private var currencyListView: some View {
        List {
            if searchText.isEmpty { popularCurrenciesSection }
            allCurrenciesSection
        }.listStyle(PlainListStyle())
    }
    private var popularCurrenciesSection: some View {
        Section("Popular Currencies") {
            ForEach(popularCurrencies, id: \.code) { currency in
                CurrencyRow(currency: currency, isSelected: currency.code == selectedCurrencyCode) {
                    selectedCurrencyCode = currency.code
                    dismiss()
                }
            }
        }
    }
    private var allCurrenciesSection: some View {
        Section(searchText.isEmpty ? "All Currencies" : "Search Results") {
            ForEach(filteredCurrencies, id: \.code) { currency in
                CurrencyRow(currency: currency, isSelected: currency.code == selectedCurrencyCode) {
                    selectedCurrencyCode = currency.code
                    dismiss()
                }
            }
        }
    }
    private var popularCurrencies: [CurrencyInfo] {
        // Show first 8 popular currencies when not searching
        Array(CurrencyService.popularCurrencies.prefix(8))
    }
    private func updateFilteredCurrencies() {
        if searchText.isEmpty {
            filteredCurrencies = currencyService.getAllCurrencies()
        } else {
            filteredCurrencies = currencyService.searchCurrencies(searchText)
        }
    }
}

struct CurrencyRow: View {
    let currency: CurrencyInfo
    let isSelected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Currency symbol
                Text(currency.symbol).font(.title2).fontWeight(.medium).frame(width: 40, alignment: .center)
                    .foregroundColor(.primary)
                // Currency info
                VStack(alignment: .leading, spacing: 2) {
                    Text(currency.name).font(.body).fontWeight(.medium).foregroundColor(.primary)
                    Text(currency.code).font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                // Selection indicator
                if isSelected { Image(systemName: "checkmark.circle.fill").foregroundColor(.blue).font(.title3) }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle()) // Ensures the entire row area is tappable
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(currency.name), \(currency.code)")
        .accessibilityHint(isSelected ? "Currently selected" : "Tap to select")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Currency Search Bar Component
struct CurrencySearchBar: View {
    @Binding var text: String
    let placeholder: String
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundColor(.secondary)
            TextField(placeholder, text: $text).textFieldStyle(PlainTextFieldStyle())
            if !text.isEmpty {
                Button(
                    action: { text = "" }, label: { Image(systemName: "xmark.circle.fill").foregroundColor(.secondary) }
                )
            }
        }.padding(.horizontal, 12).padding(.vertical, 8).background(Color.gray.opacity(0.1)).cornerRadius(10)
    }
}

#Preview { CurrencySelectionView(selectedCurrencyCode: .constant("USD")) }

