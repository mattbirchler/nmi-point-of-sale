# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

iProcess (formerly NMI-POS) is a native iOS payment processing app built with SwiftUI. It integrates with NMI's payment gateway to enable merchants to process credit card transactions, view transaction history, and analyze payment data.

## Build & Development

- **Do not build Xcode projects** - the user handles builds manually
- **Target:** iOS 17.0+
- **Swift Version:** 5.0
- **Dependencies:** None (uses only native iOS frameworks: SwiftUI, Foundation, os.log, Charts)
- **Project file:** `NMI-POS/NMI-POS.xcodeproj`

## Architecture

### State Management
- **AppState** (`AppState.swift`) - MainActor class with @Published properties managing app-wide state
- Data persistence via UserDefaults (credentials, merchant profile, settings)
- Navigation flow: Login → Welcome → Onboarding → Main

### Service Layer
- **NMIService** (`Services/NMIService.swift`) - Swift actor for thread-safe API calls
- Endpoints: `secure.nmi.com/api/query.php` (queries) and `transact.php` (transactions)
- Responses are XML (not JSON) - uses custom tag extraction parsing
- **APILogger** masks sensitive data (card numbers show last 4, security keys show first 4 + last 4)

### Key Models (`Models/Models.swift`)
- `MerchantProfile`, `NMICredentials`, `AppSettings` - Core configuration
- `Transaction`, `TransactionDetail` - Payment records
- `TransactionProduct`, `TransactionAction` - Transaction line items and history events
- `Currency` (8 currencies), `HistoryDateRange` (6 ranges), `TransactionStatus` (6 statuses)

### Views
| View | Purpose |
|------|---------|
| `LoginView` | Security key authentication |
| `WelcomeView` | Post-login welcome |
| `OnboardingView` | Currency & tax setup |
| `MainView` | Dashboard hub |
| `NewSaleView` | Payment form with receipt generation |
| `HistoryView` | Transaction list + analytics (Charts) |
| `TransactionDetailView` | Detailed transaction info |
| `SettingsView` | App configuration |

### Extensions (`Extensions/Extensions.swift`)
- String: email/card/CVV validation, card formatting
- Double: currency formatting
- Date: formatted strings
- Color: app color palette

## Code Patterns

- Async/await with Swift concurrency
- Actor pattern for NMIService (thread safety)
- MainActor for all UI state updates
- FocusState for form field management
- ImageRenderer for receipt image generation
