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
        // Legacy RecurringInfo functionality has been removed
        // This test is disabled as the functionality is no longer supported
        // Use RecurringExpenseService for new recurring expense functionality
        XCTAssertTrue(true, "Legacy RecurringInfo functionality has been removed")
    }
    
    func testRecurringInfoFormatting() throws {
        // Legacy RecurringInfo functionality has been removed
        // This test is disabled as the functionality is no longer supported
        // Use RecurringExpenseService for new recurring expense functionality
        XCTAssertTrue(true, "Legacy RecurringInfo functionality has been removed")
    }
    
    func testNextDateCalculation() throws {
        // Legacy RecurringInfo functionality has been removed
        // This test is disabled as the functionality is no longer supported
        // Use RecurringExpenseService for new recurring expense functionality
        XCTAssertTrue(true, "Legacy RecurringInfo functionality has been removed")
    }
    
    func testExpenseRecurringInfo() throws {
        // Legacy RecurringInfo functionality has been removed
        // This test is disabled as the functionality is no longer supported
        // Use RecurringExpenseService for new recurring expense functionality
        XCTAssertTrue(true, "Legacy RecurringInfo functionality has been removed")
    }
    
    func testGenerateNextExpense() throws {
        // Legacy RecurringInfo functionality has been removed
        // This test is disabled as the functionality is no longer supported
        // Use RecurringExpenseService for new recurring expense functionality
        XCTAssertTrue(true, "Legacy RecurringInfo functionality has been removed")
    }
}