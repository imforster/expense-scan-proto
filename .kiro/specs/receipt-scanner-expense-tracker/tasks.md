# Active Implementation Plan

> **📁 Archived Tasks**: Completed foundational tasks (Sections 1-3: Project Setup, Camera/Image Processing, Receipt Data Extraction) have been moved to [`tasks-archive.md`](./tasks-archive.md) to optimize token usage. Total: 9 completed tasks archived.

## Current Focus Areas

- [ ] 4. Expense Management Features
  - [x] 4.1 Implement expense categorization system
    - Create category management service
    - Build default categories and custom category support
    - Implement category suggestion algorithm
    - Add unit tests for categorization logic
    - _Requirements: 2.1, 2.2_

  - [x] 4.2 Build expense list and filtering UI
    - Create expense list view with sorting options
    - Implement filtering by date, category, amount, and vendor
    - Add search functionality
    - Build expense detail view
    - _Requirements: 2.4, 2.5_

  - [x] 4.3 Implement expense editing and management
    - Create expense editing form
    - Add support for notes and additional context
    - Implement receipt splitting functionality
    - Build recurring expense detection
    - Add unit tests for expense list logic
    - Add unit tests for expense editing and management
    - _Requirements: 2.5, 2.6, 2.7_

  - [x] 4.4 Create summary data model and basic calculations
    - Create `ExpenseListViewModel+Summaries.swift` extension file
    - Define `SummaryData` struct with title, amount, and trend properties
    - Add basic summary calculation method to compute current month total
    - Expose summary data via @Published property in ExpenseListViewModel
    - Initialize summary data with default/empty values to maintain app functionality
    - Ensure existing ExpenseListView continues to work without UI changes
    - Write unit tests for SummaryData struct initialization and basic calculations
    - **Quality Gates**: ALL TESTS MUST PASS, code builds successfully without warnings
    - Verify app builds and runs successfully with new summary infrastructure
    - _Requirements: 2.4, 3.1_

  - [x] 4.5 Implement trend calculations for summary cards
    - Add method to calculate previous month totals
    - Implement percentage change calculation between current and previous months
    - Handle edge cases for zero amounts and first month scenarios
    - Update existing summary data calculations to include trend information
    - Ensure summary data updates correctly without breaking existing functionality
    - Add unit tests for trend calculation logic
    - **Quality Gates**: ALL TESTS MUST PASS, implementation meets all task requirements
    - Verify app continues to function properly with enhanced calculations
    - _Requirements: 3.1, 3.3_

  - [x] 4.6 Update dashboard home view with real summary data
    - Update ExpenseSummaryCard to work with SummaryData model instead of raw parameters
    - Replace sample data in ContentView homeView with real summary calculations
    - Integrate ExpenseListViewModel summary data into dashboard display
    - Add loading states for summary data on dashboard
    - Ensure summary cards update when expense data changes
    - Add proper data binding between dashboard and expense data
    - Test that dashboard summary reflects actual expense data
    - Write unit tests for dashboard data integration
    - **Quality Gates**: Code follows project conventions, feature functionality verified manually
    - Verify dashboard shows accurate real-time expense summaries
    - _Requirements: 2.4, 3.1_

  - [x] 4.7 Add comprehensive unit tests for summary functionality
    - Write unit tests for SummaryData struct and calculations
    - Test edge cases for trend calculations (zero amounts, missing data)
    - Add integration tests for summary data in ExpenseListViewModel
    - Verify summary card display updates correctly with data changes
    - Test that summary functionality doesn't interfere with existing features
    - Ensure all existing ExpenseListView tests continue to pass
    - **Quality Gates**: Comprehensive test suite included and all tests passing
    - Verify complete app functionality with comprehensive test coverage
    - _Requirements: 2.4, 3.1, 3.3_

  - [x] 4.8 Implement basic recurring expense manual creation system
    - Create simple recurring expense setup UI with pattern selection (weekly, bi-weekly, monthly, quarterly)
    - Add UI for marking expenses as recurring with frequency selection and interval options
    - Implement notes-based storage for recurring information with parsing logic
    - Build method to generate upcoming expenses with duplicate prevention using date/merchant/amount matching
    - Implement UI for managing recurring expenses (view, edit, delete) in SimpleRecurringSetupView
    - Add recurring expense list view with next due dates and manual generation button
    - Add visual indicators in expense list to distinguish generated recurring expenses from templates
    - Write unit tests for recurring expense logic and duplicate prevention
    - **Quality Gates**: All tests pass, users can mark expenses as recurring and manually generate future expenses
    - Verify basic recurring expense functionality works without duplicates and shows proper visual indicators
    - _Requirements: 4.7_

  - [x] 4.9 Implement multi-currency support for expenses
    - Add currency field to Expense Core Data model with default to local currency
    - Create currency selection UI component with popular currencies and search functionality
    - Implement currency detection from receipt OCR text when possible
    - Add currency display throughout the app (expense lists, summaries, charts)
    - Build currency conversion service for reporting and analytics (optional exchange rates)
    - Update expense creation and editing flows to include currency selection
    - Add currency-specific formatting for amounts throughout the app
    - Implement currency grouping in reports and summaries
    - Write unit tests for currency handling and formatting
    - **Quality Gates**: All tests pass, expenses can be created with different currencies
    - Verify currency selection defaults to local currency and displays correctly throughout app
    - _Requirements: 2.1, 2.4, 3.1_

  - [x] 4.10 Migrate recurring expenses to proper Core Data entities
    - Create RecurringExpense and RecurringPattern Core Data entities for better data management
    - Implement proper separation between recurring templates and generated expense instances
    - Add Core Data constraints and relationships to prevent duplicate recurring templates
    - Add relationship between Expense and RecurringExpense entities for generated instances
    - Implement data migration service to convert existing notes-based recurring data to new Core Data entities
    - Add migration validation to ensure all existing recurring expenses are preserved during upgrade
    - Implement RecurringExpenseService to replace notes-based storage approach
    - Implement advanced duplicate prevention with fuzzy matching algorithms
    - Write comprehensive unit tests for Core Data entities, migration, and RecurringExpenseService
    - **Quality Gates**: All tests pass, data migration preserves existing recurring expenses, Core Data entities work correctly
    - Verify Core Data implementation works seamlessly and no user data is lost during migration
    - _Requirements: 4.7_

  - [x] 4.10.1 Update UI components to use new Core Data recurring expense entities
    - Update SimpleRecurringSetupView to create/edit RecurringExpense entities instead of storing in notes
    - Update SimpleRecurringListView to fetch RecurringExpense entities using RecurringExpenseService
    - Update ExpenseDetailView to show recurring info from recurringTemplate relationship
    - Remove dependency on notes-based RecurringInfo parsing throughout the app
    - Update RecurringExpenseHelper to use new Core Data entities or deprecate if no longer needed
    - Add proper visual indicators to distinguish recurring templates vs generated expense instances
    - Implement UI for managing RecurringExpense entities (create, edit, delete, activate/deactivate)
    - Update expense creation flow to properly link generated expenses to their recurring templates
    - Add migration trigger in app startup to convert existing notes-based data on first launch
    - Write UI tests to verify recurring expense management works with new Core Data approach
    - Validate Core Data implementation is working correctly with user testing
    - Ask user permission to cleanup old recurring expense tags/annotations from notes field after validation
    - Implement notes cleanup service to remove recurring-related annotations from migrated expenses
    - **Quality Gates**: All UI components use Core Data entities, no notes-based storage, existing functionality preserved, user approves notes cleanup
    - Verify users can create, edit, and manage recurring expenses through updated UI seamlessly
    - _Requirements: 4.7_

  - [x] 4.10.2 Add recurring expense filtering capabilities
    - Add recurring expense filter to ExpenseFiltersView with options:
      - "All Expenses" (default)
      - "Recurring Templates Only" (show RecurringExpense entities)
      - "Generated from Templates" (expenses with recurringTemplate relationship)
      - "Non-Recurring" (regular expenses)
    - Update ExpenseFilterService to support recurring status filtering
    - Integrate recurring filter with existing category, date, and amount filters
    - Add tests to verify filtering works correctly for all recurring expense types
    - **Quality Gates**: Users can filter expenses by recurring status, filter integrates with existing filters
    - _Requirements: 4.7_

  - [x] 4.10.3 Detect recurring template relationships in ExpenseEditView
    - Update ExpenseEditView to detect when editing an expense with a recurring template
    - Add UI indicators showing when an expense is linked to a recurring template
    - Display template information (pattern, next due date) in edit view
    - Add visual distinction between template-linked and regular expenses
    - Remove recurring expense editing controls from ExpenseEditView (users should manage templates separately)
    - Implement basic template relationship validation
    - Add tests to verify template detection works correctly
    - **Quality Gates**: Users can see when editing a template-linked expense, clear visual indicators, no recurring editing in ExpenseEditView
    - _Requirements: 4.7_

  - [x] 4.10.3.1 Remove recurring expense editing section from ExpenseEditView
    - Remove the recurringExpenseSection from ExpenseEditView completely
    - Remove recurring-related properties from ExpenseEditViewModel (isRecurring, recurringPattern, etc.)
    - Update ExpenseEditView to only show template information, not allow editing recurring settings
    - Ensure template-linked expenses show read-only template information only
    - Update saveExpense logic to not handle recurring expense creation/updates
    - Remove recurring expense creation functionality from expense editing flow
    - Add navigation link or button to "Manage Recurring Templates" that opens SimpleRecurringListView
    - Add tests to verify recurring editing controls are completely removed
    - **Quality Gates**: No recurring expense editing in ExpenseEditView, template info is read-only, clear path to template management
    - _Requirements: 4.7_

  - [x] 4.10.3.2 Add delete functionality for recurring expense templates
    - Add swipe-to-delete functionality in SimpleRecurringListView for recurring expense templates
    - Implement delete confirmation dialog with options to keep or delete generated expenses
    - Add delete button in recurring expense detail/edit view
    - Update RecurringExpenseService.deleteRecurringExpense method to handle both template and generated expense deletion
    - Add bulk delete functionality for multiple templates (optional)
    - Implement proper cleanup of relationships when deleting templates
    - Add undo functionality for accidental deletions (optional)
    - Add tests to verify delete functionality works correctly and doesn't leave orphaned data
    - **Quality Gates**: Users can delete recurring templates, proper cleanup of relationships, confirmation dialogs prevent accidental deletion
    - _Requirements: 4.7_

  - [ ] 4.10.4 Implement template synchronization service methods
    - Update RecurringExpenseService to provide template synchronization methods
    - Add methods for updating template from expense changes (category, amount, merchant, notes)
    - Add methods for detecting when template-linked expenses are modified
    - Implement validation to prevent orphaned recurring templates
    - Add conflict resolution for template updates from multiple expense changes
    - Add comprehensive tests for synchronization service methods
    - **Quality Gates**: Service methods handle template synchronization reliably, no data corruption
    - _Requirements: 4.7_

  - [ ] 4.10.5 Add user choice UI for template updates when editing expenses
    - Add option to "Update Template" or "Update Only This Expense" when editing template-linked expenses
    - Implement modal/alert dialog for user choice when significant changes are detected (category, amount, merchant)
    - Handle edge cases where user wants to break the link between expense and template
    - Add "Always ask" vs "Remember my choice" preferences for template updates
    - Ensure changes to core expense fields trigger the choice dialog appropriately
    - Add tests to verify user choice UI works correctly for template-linked expenses
    - **Quality Gates**: Users have control over template sync behavior, clear choice options, preferences respected
    - _Requirements: 4.7_

  - [ ] 4.10.6 Implement template synchronization from expense changes
    - Implement synchronization from expense changes to recurring templates
    - Ensure field changes (category, amount, merchant, notes, tags) can update templates when user chooses
    - Handle synchronization conflicts and edge cases gracefully
    - Add rollback capability if synchronization fails
    - Implement batch updates for multiple field changes
    - Add comprehensive integration tests for expense-to-template sync
    - **Quality Gates**: Template data updates from expense changes when requested, robust error handling, no data loss
    - _Requirements: 4.7_

  - [ ] 4.11 Add automated scheduling and notifications for recurring expenses
    - Add background task to automatically check and generate due recurring expenses
    - Build notification system for generated recurring expenses with user alerts
    - Implement scheduling service that runs periodically to check for due recurring expenses
    - Add user preferences for notification timing and frequency
    - Enhance UI with better recurring expense management (bulk operations, advanced scheduling)
    - Add recurring expense analytics and reporting features
    - Implement notification badges and in-app alerts for newly generated expenses
    - Add settings for enabling/disabling automatic generation and notifications
    - Write comprehensive unit tests for scheduling, notifications, and background processing
    - **Quality Gates**: All tests pass, background generation works automatically with notifications, users can control automation preferences
    - Verify automated scheduling works reliably without impacting app performance
    - _Requirements: 4.7_

- [ ] 5. Reporting and Analytics
  - [x] 5.1 Implement basic expense reporting
    - Create reporting service
    - Implement spending summary calculations
    - Build category-based spending analysis
    - Add time period comparison functionality
    - _Requirements: 3.1, 3.3, 3.4_

  - [x] 5.2 Build data visualization components
    - Create reusable chart components (bar, pie, line)
    - Implement spending trend visualization
    - Add interactive elements to charts
    - Write unit tests for data transformation
    - _Requirements: 3.2, 3.3_

  - [ ] 5.2.1 Create comprehensive reports view
    - Build ReportsView to replace placeholder in ContentView
    - Integrate existing chart components (bar, pie, line charts)
    - Add time period selection (weekly, monthly, yearly)
    - Implement category-based spending breakdowns
    - Add spending trend analysis with visual charts
    - Create interactive report filtering and customization
    - Integrate with ExpenseReportingService for data
    - Add proper loading states and error handling
    - Write unit tests for reports view functionality
    - **Quality Gates**: All chart components integrated, reports display real data
    - Verify reports accurately reflect expense data with proper visualizations
    - _Requirements: 3.1, 3.2, 3.3, 3.4_

  - [ ] 5.3 Implement report export functionality
    - Create export service for different formats (PDF, CSV)
    - Build export configuration UI
    - Implement file sharing options
    - Add progress indicators for export process
    - _Requirements: 3.5_

  - [ ] 5.4 Add budget tracking features
    - Implement budget setting UI
    - Create budget calculation service
    - Build notification system for budget alerts
    - Add visual indicators for budget status
    - _Requirements: 3.6_

- [ ] 6. Data Security and Synchronization
  - [ ] 6.1 Implement local authentication
    - Set up biometric authentication
    - Create app lock functionality
    - Add security timeout settings
    - Write unit tests for authentication flow
    - _Requirements: 4.2_

  - [ ] 6.2 Set up data encryption
    - Implement encryption for sensitive data
    - Create secure storage service
    - Add encryption key management
    - Write unit tests for encryption/decryption
    - _Requirements: 4.1_

  - [ ] 6.3 Implement CloudKit integration
    - Set up CloudKit container and schema
    - Create sync service for data synchronization
    - Implement conflict resolution strategies
    - Add background sync functionality
    - _Requirements: 4.3, 4.4_

  - [ ] 6.4 Add data management features
    - Implement data backup functionality
    - Create data restoration flow
    - Build data deletion options
    - Add privacy settings UI
    - _Requirements: 4.5, 4.6_

- [ ] 7. User Experience Enhancements
  - [x] 7.1 Implement light and dark mode settings
    - Create ThemeManager service for theme state management
    - Implement theme persistence using UserDefaults
    - Build SettingsView with theme selection UI (Light/Dark/System)
    - Update AppTheme with adaptive color schemes
    - Integrate theme switching throughout the app
    - Add real-time theme preview in settings
    - _Requirements: 5.1, 5.4_

  - [ ] 7.2 Implement onboarding flow
    - Create welcome screens
    - Build permission request flows
    - Add feature introduction tutorials
    - Implement onboarding skip/resume functionality
    - _Requirements: 5.1, 5.4_

  - [ ] 7.3 Add offline support
    - Implement offline receipt scanning
    - Create data queuing for sync
    - Add offline mode indicators
    - Build background sync scheduling
    - _Requirements: 5.6_

  - [ ] 7.3 Optimize performance
    - Implement image caching
    - Optimize database queries
    - Add background processing for intensive tasks
    - Implement memory usage optimizations
    - _Requirements: 5.5_

  - [ ] 7.4 Enhance accessibility features
    - Add VoiceOver support for all screens
    - Implement Dynamic Type support
    - Create accessibility labels and hints
    - Add keyboard navigation support
    - _Requirements: 5.3_

- [ ] 8. Testing and Quality Assurance
  - [x] 8.1 Implement comprehensive unit tests
    - Write tests for view models
    - Create tests for service layer
    - Implement tests for repositories
    - Add tests for utility functions
    - _Requirements: All_

  - [ ] 8.2 Create UI tests for critical flows
    - Implement tests for receipt scanning flow
    - Create tests for expense management
    - Add tests for reporting features
    - Build tests for authentication flow
    - _Requirements: All_

  - [ ] 8.3 Perform performance testing
    - Test image processing performance
    - Measure database query performance
    - Analyze memory usage patterns
    - Test battery consumption
    - _Requirements: 5.5_