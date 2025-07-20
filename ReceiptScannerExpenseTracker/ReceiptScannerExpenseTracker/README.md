# Receipt Scanner Expense Tracker

An iOS application built with SwiftUI that allows users to scan receipts using their device's camera, extract relevant information, categorize expenses, and generate reports.

## Project Structure

The project follows the MVVM (Model-View-ViewModel) architecture pattern:

### App
- Contains the main application entry point and configuration

### Models
- Core data models and entities
- Data structures that represent the application's data

### Views
- SwiftUI views for the user interface
- Organized by feature or screen

### ViewModels
- Business logic that connects models and views
- Data transformation and preparation for display

### Services
- Business logic services
- External API integrations
- Camera and OCR services

### Repositories
- Data access layer
- CRUD operations for models
- Persistence logic

### Utilities
- Helper classes and extensions
- Common UI components
- Theme and styling

### Resources
- Assets and resources
- Localization files
- Configuration files

## Requirements

- iOS 15.0+
- Xcode 13.0+
- Swift 5.5+

## Features

- Receipt scanning with camera
- OCR text extraction
- Expense categorization
- Reporting and analytics
- Data security and synchronization
- Offline support

## Getting Started

1. Clone the repository
2. Open the project in Xcode
3. Build and run on a simulator or device