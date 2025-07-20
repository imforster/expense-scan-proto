#!/bin/bash

# This script updates the project settings to make it iOS-specific

# Create a backup of the project.pbxproj file
cp ReceiptScannerExpenseTracker/ReceiptScannerExpenseTracker.xcodeproj/project.pbxproj ReceiptScannerExpenseTracker/ReceiptScannerExpenseTracker.xcodeproj/project.pbxproj.bak

# Update the project settings
sed -i '' 's/SUPPORTED_PLATFORMS = "iphoneos iphonesimulator macosx xros xrsimulator";/SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";/g' ReceiptScannerExpenseTracker/ReceiptScannerExpenseTracker.xcodeproj/project.pbxproj
sed -i '' 's/TARGETED_DEVICE_FAMILY = "1,2,7";/TARGETED_DEVICE_FAMILY = "1,2";/g' ReceiptScannerExpenseTracker/ReceiptScannerExpenseTracker.xcodeproj/project.pbxproj
sed -i '' 's/SDKROOT = auto;/SDKROOT = iphoneos;/g' ReceiptScannerExpenseTracker/ReceiptScannerExpenseTracker.xcodeproj/project.pbxproj

# Remove macOS and visionOS deployment targets
sed -i '' '/MACOSX_DEPLOYMENT_TARGET/d' ReceiptScannerExpenseTracker/ReceiptScannerExpenseTracker.xcodeproj/project.pbxproj
sed -i '' '/XROS_DEPLOYMENT_TARGET/d' ReceiptScannerExpenseTracker/ReceiptScannerExpenseTracker.xcodeproj/project.pbxproj

echo "Project settings updated to be iOS-specific."