# SVSS CRM Mobile Application

A comprehensive Flutter-based CRM application designed for **SV SOFT SOLUTIONS PVT LTD**. This app provides a mobile interface to manage leads, customers, and business tasks integrated with the SVSS API v2.0.

## 🚀 Project Overview
This application serves as a mobile extension of the SVSS CRM platform. It allows sales teams and managers to track their business activities on the go, ensuring high productivity and better customer relationship management.

## ✨ Key Features

### 1. Secure Authentication
*   **Login System:** Professional login interface with email/password validation.
*   **Token Management:** Integrated with the SVSS API for secure session handling using Bearer tokens.

### 2. Business Dashboard
*   **Performance Metrics:** Real-time counters for Leads, Customers, and Tasks.
*   **Financial Overview:** Quick glance at revenue stats (₹).
*   **Intuitive Navigation:** Grid-based layout for fast access to all modules.

### 3. Lead Management
*   **Lead Pipeline:** View potential customers in a clean, scrollable list.
*   **Status Tracking:** Color-coded badges for different stages (New, Contacted, Working, Qualified).
*   **Lead Profiling:** Quick access to contact info and source.

### 4. Customer Database
*   **Directory:** Centralized list of all converted customers and companies.
*   **Contact Info:** One-tap access to phone and email.

### 5. Task & Activity Tracker
*   **To-Do List:** Manage daily sales activities.
*   **Priority Levels:** Visual indicators for High, Medium, and Low priority tasks.
*   **Task Completion:** Interactive checkboxes to mark progress.

## 🛠 Tech Stack
*   **Framework:** Flutter (Dart)
*   **State Management:** Provider (for efficient data flow)
*   **Networking:** HTTP (REST API integration)
*   **Persistence:** Shared Preferences (for session storage)
*   **UI Design:** Material 3 (Modern Android/iOS design language)

## 📁 Project Structure
```text
lib/
├── models/         # Data structures (Lead, Customer, Task)
├── providers/      # Application state management (CRMProvider)
├── screens/        # UI Layers (Login, Dashboard, Leads, etc.)
├── services/       # Network & API logic (ApiService)
├── widgets/        # Reusable UI components
└── main.dart       # App entry point & theme configuration
```

## 🔌 API Integration
The app is built to connect with: `https://svss.in/api/docs`
*   **Base URL:** `https://svss.in/api`
*   **Auth:** Bearer Token via Header
*   **Endpoints:** Ready for `/login`, `/leads`, `/customers`, and `/tasks`.

## ⚙️ Setup & Installation
1.  **Prerequisites:** Install Flutter SDK and Android Studio.
2.  **Clone/Open:** Open the `crm_app` folder in Android Studio.
3.  **Get Packages:** Run `flutter pub get` in the terminal.
4.  **Run App:** Click the green 'Run' arrow or use `flutter run` in the terminal.

---
Developed by **SV SOFT SOLUTIONS PVT LTD** API v2.0.0 Interface Implementation.
