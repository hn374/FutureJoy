FutureJoy – Technical Design Document (Updated)
1. Overview

App Name: FutureJoy  
Platform: iOS (SwiftUI)  
Storage: SwiftData + CloudKit (prepared; container to be configured)  
Purpose:
FutureJoy helps users focus on positive anticipation by reminding them of upcoming events, releases, or moments they are looking forward to. Users add events (with emoji) and see a countdown; past events are archived and hidden.

1.0 Feature Scope (implemented)
- Home screen showing upcoming (non-archived) events.
- Create new events via sheet with emoji picker, date picker, optional category/notes.
- Local storage with SwiftData.
- CloudKit sync prepared (enable after Developer account setup).

2. Architecture
Pattern: MVVM (Model-View-ViewModel)
Justification:
- SwiftUI pairs cleanly with MVVM for state management.
- ViewModels isolate persistence/business logic from UI.
- SwiftData model integrates directly; CloudKit configured at the model layer.

2.1 Current Folder Structure (as implemented)
Forward/Forward/
│
├── Models/
│   └── Event.swift
│
├── ViewModels/
│   └── EventListViewModel.swift
│
├── Views/
│   ├── HomeView.swift
│   ├── EventRowView.swift
│   └── CreateEventView.swift
│
├── Assets.xcassets/
│   └── AccentColor (purple palette to match UI)
│
├── FutureJoyApp.swift          // App entry; SwiftData + CloudKit config
├── Forward.entitlements        // CloudKit + APS prepared
└── tech_design.md

Note: Xcode 15+ file-system-synced groups pick up files automatically; no manual PBX edits needed.

3. Data Model
Event.swift (SwiftData + CloudKit-ready)
- Properties:
  - `id: UUID` (unique)
  - `title: String`
  - `emoji: String` (required; chosen by user)
  - `date: Date`
  - `category: String?`
  - `notes: String?`
  - `isArchived: Bool` (auto-set for past events)
  - `createdAt: Date`
- Computed:
  - `daysUntil: Int` (difference from today; negative if past)
  - `isPast: Bool`
- Behavior:
  - Past events are archived via ViewModel and excluded from queries.
- CloudKit:
  - `@Model` enables SwiftData persistence; CloudKit sync is automatic once the container is configured.

4. ViewModels
EventListViewModel.swift (@MainActor, ObservableObject)
- State: `events`, `showingCreateEvent`, `eventToDelete`, `showingDeleteConfirmation`
- Persistence: owns `ModelContext`
- Fetch: non-archived events sorted ascending by date
- Archive: `archivePastEvents()` marks past events archived, then refetches
- Add: `addEvent(...)` creates and saves new Event (emoji required)
- Delete: two-step delete with confirmation (`confirmDelete`, `deleteConfirmedEvent`, `cancelDelete`)

5. Views
- HomeView.swift
  - Gradient header (purple/blue), app title, subtitle
  - “Add New Event” button (gradient) opens CreateEventView sheet
  - LazyVStack of EventRowView for non-archived events
  - Delete confirmation alert
  - On appear: archives past events, refetches
- EventRowView.swift
  - Emoji + title row, delete (trash) button
  - Formatted date
  - Days countdown badge with gradient
- CreateEventView.swift
  - Emoji picker grid (popular emojis), required
  - Title (required), DatePicker (future dates only), optional category/notes
  - Validation disables Save until required fields valid
  - Saves via ViewModel, dismisses sheet

UI Theme:
- Gradients and purple accent matching provided mock.
- AccentColor updated to purple palette in Assets.xcassets.

6. Services (planned / not yet implemented)
- NotificationService.swift (future): schedule local notifications for upcoming events.
- CloudSyncService.swift (future): custom CloudKit behaviors if needed; base sync already via SwiftData + CloudKit.

7. App Flow (ASCII Diagram)
+------------------+        +-------------------+        +------------------+
|                  |        |                   |        |                  |
|     HomeView     |  <-->  | EventListViewModel|  <-->  |      Event       |
|  (list + sheet)  |        |                   |        |    (SwiftData)   |
+------------------+        +-------------------+        +------------------+
        |                           ^
        | "Add Event" button        | fetch / save / delete / archive past
        v                           |
+------------------+                 |
|                  |                 |
| CreateEventView  |-----------------+
|  (emoji + form)  |
+------------------+

CloudKit will sync Event data once the container is configured in Signing & Capabilities.

8. Testing (to add)
- Unit: Event model (`daysUntil`), EventListViewModel (add, fetch, archive, delete)
- UI: HomeView list rendering, CreateEventView form validation/save, delete confirmation

9. Future Extensions
- Push notifications for upcoming events (NotificationService)
- Rich categories with icons/colors
- Sorting & filtering (by date, category)
- Widget for next event
- Dark mode polish (SwiftUI auto, adjust gradients)
- Reminders and repeat notifications
- Calendar import/export

10. Notes on CloudKit & SwiftData
- Each user’s data lives in their private iCloud database (once enabled).
- No backend required; CloudKit handles sync.
- Offline works automatically; syncs on reconnect.
- Future: public/shared databases if event sharing is needed.

11. Setup Checklist for CloudKit (post Developer account)
- In Xcode Signing & Capabilities: enable iCloud + CloudKit, add container (e.g., `iCloud.<bundle-id>`).
- Ensure `Forward.entitlements` lists the container (currently templated with `iCloud.$(PRODUCT_BUNDLE_IDENTIFIER)`).
- Keep `cloudKitDatabase: .automatic` in `FutureJoyApp.swift` ModelConfiguration.