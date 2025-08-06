//
//  SimpleRecurringExpenseTests.swift
//  ReceiptScannerExpenseTrackerTests
//
//  Created by Kiro on 8/4/25.
//

import XCTest
import CoreData
@testable import ReceiptScannerExpenseTracker

final class SimpleRecurringExpenseTests: XCTestCase {
    var testContext: NSManagedObjectContext!
    
    override func setUpWithError() throws {
        // Create in-memory Core Data stack for testing
        let container = NSPersistentContainer(name: "ReceiptScannerExpenseTracker")
        container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        
        container.loadPersistentStores { _, error in
            if let error = error {
                XCTFail("Failed to load store: \(error)")
            }
        }
        
        testContext = container.viewContext
    }
    
    override func tearDownWithError() throws {
        testContext = nil
    }
    
    func testRecurringInfoParsing() throws {
        // Test parsing monthly recurring info
        let monthlyNotes = "Test expense [Recurring: monthly, interval:1, day:15]"
        let monthlyInfo = RecurringInfo.parse(from: monthlyNotes)
        
        XCTAssertNotNil(monthlyInfo)
        XCTAssertEqual(monthlyInfo?.pattern, .monthly)
        XCTAssertEqual(monthlyInfo?.interval, 1)
        XCTAssertEqual(monthlyInfo?.dayOfMonth, 15)
        
        // Test parsing weekly recurring info
        let weeklyNotes = "Another expense [Recurring: weekly, interval:2]"
        let weeklyInfo = RecurringInfo.parse(from: weeklyNotes)
        
        XCTAssertNotNil(weeklyInfo)
        XCTAssertEqual(weeklyInfo?.pattern, .weekly)
        XCTAssertEqual(weeklyInfo?.interval, 2)
        XCTAssertNil(weeklyInfo?.dayOfMonth)
    }
    
    func testRecurringInfoFormatting() throws {
        let info = RecurringInfo(pattern: .monthly, interval: 1, dayOfMonth: 15)
        let formatted = info.toNotesFormat()
        
        XCTAssertEqual(formatted, "[Recurring: monthly, day:15]")
        
        let weeklyInfo = RecurringInfo(pattern: .weekly, interval: 2)
        let weeklyFormatted = weeklyInfo.toNotesFormat()
        
        XCTAssertEqual(weeklyFormatted, "[Recurring: weekly, interval:2]")
    }
    
    func testNextDateCalculation() throws {
        let calendar = Calendar.current
        let baseDate = calendar.date(from: DateComponents(year: 2024, month: 1, day: 15))!
        
        // Test monthly with specific day
        let monthlyInfo = RecurringInfo(pattern: .monthly, interval: 1, dayOfMonth: 15)
        let nextMonthly = monthlyInfo.calculateNextDate(from: baseDate)
        let expectedMonthly = calendar.date(from: DateComponents(year: 2024, month: 2, day: 15))!
        
        XCTAssertEqual(calendar.compare(nextMonthly, to: expectedMonthly, toGranularity: .day), .orderedSame)
        
        // Test weekly
        let weeklyInfo = RecurringInfo(pattern: .weekly, interval: 1)
        let nextWeekly = weeklyInfo.calculateNextDate(from: baseDate)
        let expectedWeekly = calendar.date(byAdding: .weekOfYear, value: 1, to: baseDate)!
        
        XCTAssertEqual(calendar.compare(nextWeekly, to: expectedWeekly, toGranularity: .day), .orderedSame)
    }
    
    func testExpenseRecurringInfo() throws {
        // Create test expense
        let expense = Expense(context: testContext)
        expense.id = UUID()
        expense.amount = NSDecimalNumber(string: "25.99")
        expense.date = Date()
        expense.merchant = "Test Merchant"
        expense.isRecurring = false
        
        // Set recurring info
        let recurringInfo = RecurringInfo(pattern: .monthly, interval: 1, dayOfMonth: 15)
        expense.setRecurringInfo(recurringInfo)
        
        // Verify it was set correctly
        XCTAssertTrue(expense.isRecurring)
        XCTAssertNotNil(expense.recurringInfo)
        XCTAssertEqual(expense.recurringInfo?.pattern, .monthly)
        XCTAssertEqual(expense.recurringInfo?.dayOfMonth, 15)
        XCTAssertNotNil(expense.nextRecurringDate)
    }
    
    func testGenerateNextExpense() throws {
        // Create recurring expense
        let template = Expense(context: testContext)
        template.id = UUID()
        template.amount = NSDecimalNumber(string: "50.00")
        template.date = Date()
        template.merchant = "Monthly Service"
        template.paymentMethod = "Credit Card"
        
        let recurringInfo = RecurringInfo(pattern: .monthly, interval: 1)
        template.setRecurringInfo(recurringInfo)
        
        // Generate next expense
        let generated = RecurringExpenseHelper.generateNextExpense(from: template, context: testContext)
        
        XCTAssertNotNil(generated)
        XCTAssertEqual(generated?.amount, template.amount)
        XCTAssertEqual(generated?.merchant, template.merchant)
        XCTAssertEqual(generated?.paymentMethod, template.paymentMethod)
        XCTAssertFalse(generated?.isRecurring ?? true) // Generated expenses should not be recurring
        XCTAssertTrue(generated?.notes?.contains("Generated from recurring expense") ?? false)
    }
}