import XCTest
import CoreData
@testable import ReceiptScannerExpenseTracker

final class RecurringExpenseCoreDataTests: CoreDataTestCase {
    
    var testCategory: ReceiptScannerExpenseTracker.Category!
    var testTag: Tag!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Create test category
        testCategory = ReceiptScannerExpenseTracker.Category(context: testContext)
        testCategory.id = UUID()
        testCategory.name = "Test Category"
        testCategory.colorHex = "FF0000"
        testCategory.icon = "test.icon"
        
        // Create test tag
        testTag = Tag(context: testContext)
        testTag.id = UUID()
        testTag.name = "Test Tag"
        
        try testContext.save()
    }
    
    // MARK: - RecurringExpense Entity Tests
    
    func testCreateRecurringExpense() throws {
        let recurringExpense = RecurringExpense(context: testContext)
        recurringExpense.id = UUID()
        recurringExpense.amount = NSDecimalNumber(string: "50.00")
        recurringExpense.currencyCode = "USD"
        recurringExpense.merchant = "Test Merchant"
        recurringExpense.notes = "Test notes"
        recurringExpense.paymentMethod = "Credit Card"
        recurringExpense.isActive = true
        recurringExpense.createdDate = Date()
        recurringExpense.category = testCategory
        recurringExpense.addToTags(testTag)
        
        try testContext.save()
        
        XCTAssertNotNil(recurringExpense.id)
        XCTAssertEqual(recurringExpense.amount, NSDecimalNumber(string: "50.00"))
        XCTAssertEqual(recurringExpense.currencyCode, "USD")
        XCTAssertEqual(recurringExpense.merchant, "Test Merchant")
        XCTAssertEqual(recurringExpense.notes, "Test notes")
        XCTAssertEqual(recurringExpense.paymentMethod, "Credit Card")
        XCTAssertTrue(recurringExpense.isActive)
        XCTAssertNotNil(recurringExpense.createdDate)
        XCTAssertEqual(recurringExpense.category, testCategory)
        XCTAssertTrue(recurringExpense.safeTags.contains(testTag))
    }
    
    func testRecurringExpenseFormattedAmount() throws {
        let recurringExpense = RecurringExpense(context: testContext)
        recurringExpense.id = UUID()
        recurringExpense.amount = NSDecimalNumber(string: "123.45")
        recurringExpense.currencyCode = "USD"
        recurringExpense.merchant = "Format Test"
        recurringExpense.isActive = true
        recurringExpense.createdDate = Date()
        
        try testContext.save()
        
        let formattedAmount = recurringExpense.formattedAmount()
        XCTAssertTrue(formattedAmount.contains("123.45"))
    }
    
    func testRecurringExpenseCalculateNextDueDate() throws {
        let baseDate = Date()
        
        let recurringExpense = RecurringExpense(context: testContext)
        recurringExpense.id = UUID()
        recurringExpense.amount = NSDecimalNumber(string: "100.00")
        recurringExpense.currencyCode = "USD"
        recurringExpense.merchant = "Due Date Test"
        recurringExpense.isActive = true
        recurringExpense.createdDate = baseDate
        
        let pattern = RecurringPatternEntity(context: testContext)
        pattern.id = UUID()
        pattern.patternType = "Monthly"
        pattern.interval = 1
        pattern.dayOfMonth = 15
        pattern.nextDueDate = baseDate
        
        recurringExpense.pattern = pattern
        
        try testContext.save()
        
        let nextDueDate = recurringExpense.calculateNextDueDate()
        XCTAssertNotEqual(nextDueDate, baseDate)
        
        let calendar = Calendar.current
        let nextMonth = calendar.dateComponents([.year, .month], from: baseDate)
        var expectedComponents = nextMonth
        expectedComponents.day = 15
        expectedComponents.month = (expectedComponents.month ?? 1) + 1
        
        let expectedDate = calendar.date(from: expectedComponents)
        XCTAssertNotNil(expectedDate)
    }
    
    func testRecurringExpenseIsDue() throws {
        let pastDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let futureDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        
        // Test due expense (past due date)
        let dueExpense = RecurringExpense(context: testContext)
        dueExpense.id = UUID()
        dueExpense.amount = NSDecimalNumber(string: "50.00")
        dueExpense.currencyCode = "USD"
        dueExpense.merchant = "Due Test"
        dueExpense.isActive = true
        dueExpense.createdDate = Date()
        
        let duePattern = RecurringPatternEntity(context: testContext)
        duePattern.id = UUID()
        duePattern.patternType = "Weekly"
        duePattern.interval = 1
        duePattern.nextDueDate = pastDate
        
        dueExpense.pattern = duePattern
        
        // Test not due expense (future due date)
        let notDueExpense = RecurringExpense(context: testContext)
        notDueExpense.id = UUID()
        notDueExpense.amount = NSDecimalNumber(string: "75.00")
        notDueExpense.currencyCode = "USD"
        notDueExpense.merchant = "Not Due Test"
        notDueExpense.isActive = true
        notDueExpense.createdDate = Date()
        
        let notDuePattern = RecurringPatternEntity(context: testContext)
        notDuePattern.id = UUID()
        notDuePattern.patternType = "Monthly"
        notDuePattern.interval = 1
        notDuePattern.nextDueDate = futureDate
        
        notDueExpense.pattern = notDuePattern
        
        try testContext.save()
        
        XCTAssertTrue(dueExpense.isDue)
        XCTAssertFalse(notDueExpense.isDue)
    }
    
    func testRecurringExpenseGenerateExpense() throws {
        let pastDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        
        let recurringExpense = RecurringExpense(context: testContext)
        recurringExpense.id = UUID()
        recurringExpense.amount = NSDecimalNumber(string: "200.00")
        recurringExpense.currencyCode = "USD"
        recurringExpense.merchant = "Generate Test"
        recurringExpense.notes = "Template notes"
        recurringExpense.paymentMethod = "Debit Card"
        recurringExpense.isActive = true
        recurringExpense.createdDate = Date()
        recurringExpense.category = testCategory
        recurringExpense.addToTags(testTag)
        
        let pattern = RecurringPatternEntity(context: testContext)
        pattern.id = UUID()
        pattern.patternType = "Weekly"
        pattern.interval = 1
        pattern.nextDueDate = pastDate
        
        recurringExpense.pattern = pattern
        
        try testContext.save()
        
        let generatedExpense = recurringExpense.generateExpense(context: testContext)
        
        XCTAssertNotNil(generatedExpense)
        XCTAssertEqual(generatedExpense?.amount, recurringExpense.amount)
        XCTAssertEqual(generatedExpense?.currencyCode, recurringExpense.currencyCode)
        XCTAssertEqual(generatedExpense?.merchant, recurringExpense.merchant)
        XCTAssertEqual(generatedExpense?.notes, recurringExpense.notes)
        XCTAssertEqual(generatedExpense?.paymentMethod, recurringExpense.paymentMethod)
        XCTAssertEqual(generatedExpense?.category, recurringExpense.category)
        XCTAssertEqual(generatedExpense?.recurringTemplate, recurringExpense)
        XCTAssertFalse(generatedExpense?.isRecurring ?? true)
        XCTAssertTrue(generatedExpense?.safeTags.contains(testTag) ?? false)
        XCTAssertNotNil(recurringExpense.lastGeneratedDate)
    }
    
    func testRecurringExpenseGenerateExpenseWhenInactive() throws {
        let recurringExpense = RecurringExpense(context: testContext)
        recurringExpense.id = UUID()
        recurringExpense.amount = NSDecimalNumber(string: "100.00")
        recurringExpense.currencyCode = "USD"
        recurringExpense.merchant = "Inactive Test"
        recurringExpense.isActive = false // Inactive
        recurringExpense.createdDate = Date()
        
        let pattern = RecurringPatternEntity(context: testContext)
        pattern.id = UUID()
        pattern.patternType = "Monthly"
        pattern.interval = 1
        pattern.nextDueDate = Date()
        
        recurringExpense.pattern = pattern
        
        try testContext.save()
        
        let generatedExpense = recurringExpense.generateExpense(context: testContext)
        
        XCTAssertNil(generatedExpense)
    }
    
    // MARK: - RecurringPatternEntity Tests
    
    func testCreateRecurringPattern() throws {
        let pattern = RecurringPatternEntity(context: testContext)
        pattern.id = UUID()
        pattern.patternType = "Monthly"
        pattern.interval = 2
        pattern.dayOfMonth = 15
        pattern.dayOfWeek = 0
        pattern.nextDueDate = Date()
        
        try testContext.save()
        
        XCTAssertNotNil(pattern.id)
        XCTAssertEqual(pattern.patternType, "Monthly")
        XCTAssertEqual(pattern.interval, 2)
        XCTAssertEqual(pattern.dayOfMonth, 15)
        XCTAssertEqual(pattern.dayOfWeek, 0)
        XCTAssertNotNil(pattern.nextDueDate)
    }
    
    func testRecurringPatternCalculateNextDateWeekly() throws {
        let baseDate = Date()
        
        let pattern = RecurringPatternEntity(context: testContext)
        pattern.id = UUID()
        pattern.patternType = "Weekly"
        pattern.interval = 2
        pattern.nextDueDate = baseDate
        
        try testContext.save()
        
        let nextDate = pattern.calculateNextDate(from: baseDate)
        let expectedDate = Calendar.current.date(byAdding: .weekOfYear, value: 2, to: baseDate)!
        
        let calendar = Calendar.current
        let nextComponents = calendar.dateComponents([.year, .month, .day], from: nextDate)
        let expectedComponents = calendar.dateComponents([.year, .month, .day], from: expectedDate)
        
        XCTAssertEqual(nextComponents.year, expectedComponents.year)
        XCTAssertEqual(nextComponents.month, expectedComponents.month)
        XCTAssertEqual(nextComponents.day, expectedComponents.day)
    }
    
    func testRecurringPatternCalculateNextDateMonthlyWithSpecificDay() throws {
        let calendar = Calendar.current
        let baseDate = calendar.date(from: DateComponents(year: 2024, month: 1, day: 10))!
        
        let pattern = RecurringPatternEntity(context: testContext)
        pattern.id = UUID()
        pattern.patternType = "Monthly"
        pattern.interval = 1
        pattern.dayOfMonth = 15
        pattern.nextDueDate = baseDate
        
        try testContext.save()
        
        let nextDate = pattern.calculateNextDate(from: baseDate)
        let expectedDate = calendar.date(from: DateComponents(year: 2024, month: 1, day: 15))!
        
        let nextComponents = calendar.dateComponents([.year, .month, .day], from: nextDate)
        let expectedComponents = calendar.dateComponents([.year, .month, .day], from: expectedDate)
        
        XCTAssertEqual(nextComponents.year, expectedComponents.year)
        XCTAssertEqual(nextComponents.month, expectedComponents.month)
        XCTAssertEqual(nextComponents.day, expectedComponents.day)
    }
    
    func testRecurringPatternCalculateNextDateQuarterly() throws {
        let baseDate = Date()
        
        let pattern = RecurringPatternEntity(context: testContext)
        pattern.id = UUID()
        pattern.patternType = "Quarterly"
        pattern.interval = 1
        pattern.nextDueDate = baseDate
        
        try testContext.save()
        
        let nextDate = pattern.calculateNextDate(from: baseDate)
        let expectedDate = Calendar.current.date(byAdding: .month, value: 3, to: baseDate)!
        
        let calendar = Calendar.current
        let nextComponents = calendar.dateComponents([.year, .month, .day], from: nextDate)
        let expectedComponents = calendar.dateComponents([.year, .month, .day], from: expectedDate)
        
        XCTAssertEqual(nextComponents.year, expectedComponents.year)
        XCTAssertEqual(nextComponents.month, expectedComponents.month)
        XCTAssertEqual(nextComponents.day, expectedComponents.day)
    }
    
    func testRecurringPatternDescription() throws {
        // Test weekly pattern
        let weeklyPattern = RecurringPatternEntity(context: testContext)
        weeklyPattern.id = UUID()
        weeklyPattern.patternType = "Weekly"
        weeklyPattern.interval = 1
        weeklyPattern.nextDueDate = Date()
        
        XCTAssertEqual(weeklyPattern.description, "Weekly")
        
        // Test bi-weekly pattern
        let biweeklyPattern = RecurringPatternEntity(context: testContext)
        biweeklyPattern.id = UUID()
        biweeklyPattern.patternType = "Biweekly"
        biweeklyPattern.interval = 1
        biweeklyPattern.nextDueDate = Date()
        
        XCTAssertEqual(biweeklyPattern.description, "Bi-weekly")
        
        // Test monthly pattern with specific day
        let monthlyPattern = RecurringPatternEntity(context: testContext)
        monthlyPattern.id = UUID()
        monthlyPattern.patternType = "Monthly"
        monthlyPattern.interval = 1
        monthlyPattern.dayOfMonth = 15
        monthlyPattern.nextDueDate = Date()
        
        XCTAssertEqual(monthlyPattern.description, "Monthly on the 15th")
        
        // Test quarterly pattern
        let quarterlyPattern = RecurringPatternEntity(context: testContext)
        quarterlyPattern.id = UUID()
        quarterlyPattern.patternType = "Quarterly"
        quarterlyPattern.interval = 2
        quarterlyPattern.nextDueDate = Date()
        
        XCTAssertEqual(quarterlyPattern.description, "Every 2 quarters")
        
        try testContext.save()
    }
    
    // MARK: - Relationship Tests
    
    func testRecurringExpensePatternRelationship() throws {
        let recurringExpense = RecurringExpense(context: testContext)
        recurringExpense.id = UUID()
        recurringExpense.amount = NSDecimalNumber(string: "150.00")
        recurringExpense.currencyCode = "USD"
        recurringExpense.merchant = "Relationship Test"
        recurringExpense.isActive = true
        recurringExpense.createdDate = Date()
        
        let pattern = RecurringPatternEntity(context: testContext)
        pattern.id = UUID()
        pattern.patternType = "Monthly"
        pattern.interval = 1
        pattern.nextDueDate = Date()
        
        recurringExpense.pattern = pattern
        
        try testContext.save()
        
        XCTAssertEqual(recurringExpense.pattern, pattern)
        XCTAssertEqual(pattern.recurringExpense, recurringExpense)
    }
    
    func testRecurringExpenseGeneratedExpensesRelationship() throws {
        let recurringExpense = RecurringExpense(context: testContext)
        recurringExpense.id = UUID()
        recurringExpense.amount = NSDecimalNumber(string: "75.00")
        recurringExpense.currencyCode = "USD"
        recurringExpense.merchant = "Generated Relationship Test"
        recurringExpense.isActive = true
        recurringExpense.createdDate = Date()
        
        let pattern = RecurringPatternEntity(context: testContext)
        pattern.id = UUID()
        pattern.patternType = "Weekly"
        pattern.interval = 1
        pattern.nextDueDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        
        recurringExpense.pattern = pattern
        
        try testContext.save()
        
        // Generate an expense
        let generatedExpense = recurringExpense.generateExpense(context: testContext)
        XCTAssertNotNil(generatedExpense)
        
        try testContext.save()
        
        XCTAssertTrue(recurringExpense.safeGeneratedExpenses.contains(generatedExpense!))
        XCTAssertEqual(generatedExpense?.recurringTemplate, recurringExpense)
    }
    
    func testRecurringExpenseCategoryRelationship() throws {
        let recurringExpense = RecurringExpense(context: testContext)
        recurringExpense.id = UUID()
        recurringExpense.amount = NSDecimalNumber(string: "125.00")
        recurringExpense.currencyCode = "USD"
        recurringExpense.merchant = "Category Relationship Test"
        recurringExpense.isActive = true
        recurringExpense.createdDate = Date()
        recurringExpense.category = testCategory
        
        try testContext.save()
        
        XCTAssertEqual(recurringExpense.category, testCategory)
        XCTAssertTrue(testCategory.safeRecurringExpenses.contains(recurringExpense))
    }
    
    func testRecurringExpenseTagsRelationship() throws {
        let recurringExpense = RecurringExpense(context: testContext)
        recurringExpense.id = UUID()
        recurringExpense.amount = NSDecimalNumber(string: "85.00")
        recurringExpense.currencyCode = "USD"
        recurringExpense.merchant = "Tags Relationship Test"
        recurringExpense.isActive = true
        recurringExpense.createdDate = Date()
        recurringExpense.addToTags(testTag)
        
        try testContext.save()
        
        XCTAssertTrue(recurringExpense.safeTags.contains(testTag))
        XCTAssertTrue(testTag.safeRecurringExpenses.contains(recurringExpense))
    }
    
    // MARK: - Fetch Request Tests
    
    func testRecurringExpenseFetchRequest() throws {
        let recurringExpense1 = RecurringExpense(context: testContext)
        recurringExpense1.id = UUID()
        recurringExpense1.amount = NSDecimalNumber(string: "50.00")
        recurringExpense1.currencyCode = "USD"
        recurringExpense1.merchant = "Fetch Test 1"
        recurringExpense1.isActive = true
        recurringExpense1.createdDate = Date()
        
        let recurringExpense2 = RecurringExpense(context: testContext)
        recurringExpense2.id = UUID()
        recurringExpense2.amount = NSDecimalNumber(string: "75.00")
        recurringExpense2.currencyCode = "USD"
        recurringExpense2.merchant = "Fetch Test 2"
        recurringExpense2.isActive = false
        recurringExpense2.createdDate = Date()
        
        try testContext.save()
        
        let fetchRequest = RecurringExpense.fetchRequest()
        let allRecurringExpenses = try testContext.fetch(fetchRequest)
        
        XCTAssertEqual(allRecurringExpenses.count, 2)
        
        // Test filtering by active status
        fetchRequest.predicate = NSPredicate(format: "isActive == YES")
        let activeRecurringExpenses = try testContext.fetch(fetchRequest)
        
        XCTAssertEqual(activeRecurringExpenses.count, 1)
        XCTAssertEqual(activeRecurringExpenses.first?.merchant, "Fetch Test 1")
    }
    
    func testRecurringPatternFetchRequest() throws {
        let pattern1 = RecurringPatternEntity(context: testContext)
        pattern1.id = UUID()
        pattern1.patternType = "Weekly"
        pattern1.interval = 1
        pattern1.nextDueDate = Date()
        
        let pattern2 = RecurringPatternEntity(context: testContext)
        pattern2.id = UUID()
        pattern2.patternType = "Monthly"
        pattern2.interval = 2
        pattern2.nextDueDate = Date()
        
        try testContext.save()
        
        let fetchRequest = RecurringPatternEntity.fetchRequest()
        let allPatterns = try testContext.fetch(fetchRequest)
        
        XCTAssertEqual(allPatterns.count, 2)
        
        // Test filtering by pattern type
        fetchRequest.predicate = NSPredicate(format: "patternType == %@", "Weekly")
        let weeklyPatterns = try testContext.fetch(fetchRequest)
        
        XCTAssertEqual(weeklyPatterns.count, 1)
        XCTAssertEqual(weeklyPatterns.first?.patternType, "Weekly")
    }
}