# MyHostel

Flutter app (Android + iOS) for running a college hostel, backed by Firebase
Auth and Cloud Firestore. Two roles: **Super Admin** and **Student**.

## What is built

| Phase | Scope | Status |
|-------|-------|--------|
| 1 | Sign-in, roles, theme (light/dark), navigation | Done |
| 2 | Dashboard: overview cards, needs attention, quick actions, recent activity | Done |
| 3 | Student records and room/bed allocation | Done, except file uploads |
| 4 | Fees, payments, receipts | Not started |
| 5 | Leave: vacation applications with approve and reject | Done |
| 6 | Mess (guest meal, extra meal, tiffin menus and orders) and complaints | Done |
| 6 | Notices: draft, publish, edit, archive; students notified in the app | Done |
| 6 | Push notifications | Not started |
| 7 | Reports: students, occupancy, fees, vacations, complaints, meals; PDF export | Done |
| – | Hostel settings (daily fees, charges, payment rules, hostel details) | Done |

Modules that are not started open a screen that says so. The dashboard already
counts their collections, so those cards show zero until the module exists.

Attendance is deliberately not part of the app.

### Mess admin

A third role, `mess_admin`, for the mess operator. A smaller app than the
super admin's:

| Area | What the mess admin can do |
|------|----------------------------|
| Mess | Same as the super admin: menus and orders for guest meals, extra meals, tiffin |
| Mess fees | See mess bills by month and overdue ones; verify or reject students' mess payments; record mess payments taken in person. No hostel rent. |
| Leave | See vacation applications, without approve or reject |
| Complaints | Mess Quality complaints only; reply, mark in progress or resolved |
| Notices | See all published notices; write and publish their own, and edit, archive or delete only those |
| Reports | Mess-only report: mess fees, meal orders, mess complaints, leave |

Not available to the mess admin: registration requests, students list,
rooms and beds, hostel rent, billing set-up, hostel settings, the activity
feed. The security rules enforce all of this, not just the screens.

To make someone a mess admin, create their login in the Firebase console
(Authentication > Users > Add user), then:

```powershell
dart run tool/firebase_admin.dart set-role their@email.com mess_admin
```

### Student app

| Phase | Scope | Status |
|-------|-------|--------|
| 1 | Student shell, five tabs, home with live profile, room, bills and notifications | Done |
| 2 | Automatic monthly bills and the admin Fees list | Done; PDF bills not started |
| 3 | Paying each month's bill separately (cash, UPI, bank transfer) with office verification | Done; PDF receipts not started |
| 4 | Online payments (needs Cloud Functions and a gateway account) | Not started |
| 5 | Vacation applications (at least the minimum days) with mess fee deduction | Done |
| 6 | Guest meals, extra meals, tiffin, charged to the next mess bill | Done |
| 7 | Room maintenance and complaints, in-app notifications | Done; push notifications and photos not started |
| 8 | Final rules, backend validation, deployment | Not started |

#### Billing rule

- Nothing is billed in the month a student joins.
- Their first bill is for the following month and has two lines: the days
  from the joining date to the end of the joining month (joining day
  included), and the full following month.
- Every later month is billed in full: days in the month × the daily rate.
- Internet and other monthly charges go on the hostel bill, full months only.
- A bill's id is `{studentId}_{yyyy-MM}`, so it can never be created twice,
  and an issued bill is never recalculated when rates change.

#### Payments

- Each month's bill is paid on its own. A student opens a bill and sends a
  payment for its full balance (cash, UPI or bank transfer); it is stored in
  `payments` as `awaiting_verification` and changes nothing yet.
- The office verifies or rejects it. Verifying reduces that one bill, marks
  the payment `paid`, adds to `fee_summaries/{yyyy-MM}.collectedPaise`, logs
  it and notifies the student, all in one transaction. The app has no way to
  undo a verified payment.
- The office can also record money it received directly, for all or part of
  a bill.
- The rules let a student create a payment only as awaiting verification,
  only for their own bill, and only for that bill's exact balance.

#### Vacation deduction

- A vacation must be at least `vacationMinDays` days (10 by default),
  counting both ends.
- On approval the deduction is fixed: days away × the daily mess fee. It is
  stored on the leave (`deductionAmount`, `deductionApplied`).
- It comes off the first new mess bill for a month after the vacation ends,
  as a negative line, and is marked applied in the same transaction so it is
  never deducted twice. Hostel rent is not reduced. A bill never goes below
  zero.

There is no server, so bills are created by the admin's app: the first bill
when a student is admitted, and each new month's bills the first time the
admin opens the app in that month (or taps the sync button on the Fees tab).

Bills live in `hostel_bills` and `mess_bills` (kept separate). Each has
`studentId`, `period` (`yyyy-MM`), `total` and `paid` in **paise**, `status`,
`dueDate`, and `items` (`label`, `amount`; deductions are negative). A student
can read only their own bills and cannot write them.

Not built in phase 3: photo and document **file uploads**. They need Firebase
Storage, which requires the Blaze (pay-as-you-go) plan. Until then the student
record has a checklist of which documents the office has received.

## Setup

### 1. Generate the platform folders (once)

```powershell
.\setup.ps1
```

The app id is `com.abhishek.hostelmanagement`, which is what the Android and
iOS apps are registered as in Firebase. If you change `--org` or
`--project-name` in `setup.ps1`, register matching apps in Firebase too.

### 2. Connect Firebase

1. Build > Authentication > Sign-in method: enable **Email/Password**.
2. Build > Firestore Database: create the database.
3. Firestore > Rules: paste the contents of `firestore.rules` and **Publish**.
   Do this again whenever `firestore.rules` changes; the app gets
   "permission denied" errors until the published rules match.
4. `lib/firebase_options.dart` already holds the keys for the
   `hostel-management-42d65` project.

No composite indexes are needed for anything built so far.

#### Publishing rules from this PC instead of the console

With a service account key saved as `service-account.json` in this folder
(Project settings > Service accounts > Generate new private key):

```powershell
$env:PATH = "C:\flutter\bin\mingit\cmd;$env:PATH"   # only if git is not installed
dart run tool/firebase_admin.dart deploy-rules      # publish firestore.rules
dart run tool/firebase_admin.dart init              # create the zeroed summary docs
dart run tool/firebase_admin.dart status            # list the collections
```

The key gives full access to the project. It is git-ignored; never share it.

### 3. Create the super admin

The super admin cannot sign up in the app:

1. Authentication > Users > **Add user** (email + password). Copy the User UID.
2. Firestore > `users` collection > add a document whose **ID is that UID**:

| Field    | Type   | Value         |
|----------|--------|---------------|
| `name`   | string | Their name    |
| `email`  | string | Their email   |
| `role`   | string | `super_admin` |
| `status` | string | `approved`    |

### 4. Run and test

```powershell
flutter run      # on a connected phone or emulator
flutter test     # unit and widget tests
```

iOS builds need a Mac with Xcode.

## Code layout

```
lib/
  main.dart
  app/            app.dart, router.dart, theme/, constants/
  core/           errors/, services/ (Riverpod providers), utils/, widgets/
  features/       auth/, dashboard/, students/, rooms/, profile/, student/
  models/
  repositories/   all Firestore access
```

State management is Riverpod. Screens never touch Firestore directly; they go
through a repository.

## Data model

- `users/{uid}`: login profile. `role` (`student` | `super_admin`), `status`
  (`pending` | `approved` | `rejected`), `name`, `email`, `phone`.
- `students/{id}`: hostel record. For a student who registered in the app the
  id is their uid. `status` (`active` | `vacated`), contact, college and
  guardian details, `roomId`, `roomNumber`, `bedId`, `bedLabel`, `documents`,
  `documentsComplete`, `admissionDate`, `exitDate`, `exitReason`, and
  `sortKey` (`status|lowercase name`) which the list is ordered and searched by.
- `rooms/{roomNumber}`: `number`, `floor`, `type`, `capacity`,
  `occupiedCount`, `maintenanceStatus` (`ok` | `needs_repair` |
  `under_repair`), `maintenanceNote`.
- `beds/{roomId_label}`: `roomId`, `roomNumber`, `label`, `occupied`,
  `studentId`, `studentName`.
- `hostel_settings/main`: `hostelFeePerDay`, `messFeePerDay`,
  `internetFeePerMonth`, `otherFeePerMonth` (all in paise), `otherFeeLabel`,
  `dueDayOfMonth`, `lateFinePerDay`, `lateFineGraceDays`, `vacationMinDays`,
  and the hostel's name, address and contact details. Readable by any
  signed-in user; written only by the super admin. Fee changes are logged
  with the old and new amounts.
- `leaves/{id}`: vacation applications. `studentId`, `fromDate`, `toDate`,
  `days`, `reason`, `status` (`pending` | `approved` | `rejected`),
  `remarks`, and `approvedUntil` (set on approval only).
- `complaints/{id}`: complaints and maintenance requests. `kind`
  (`complaint` | `maintenance`), `category`, `title`, `description`, `status`
  (`pending` | `in_progress` | `resolved`), `adminNote`.
- `meal_items/{id}`: menus. `service` (`guest` | `extra` | `tiffin`), `name`,
  `category`, `price` (paise), `available`.
- `meal_orders/{id}`: `service`, `studentId`, `itemId`, `itemName`,
  `unitPrice`, `quantity`, `total`, `mealDate`, `status`, `billed`, `billId`.
  The rules check the price and total against the menu. A confirmed order is
  added to the student's next new mess bill and marked `billed` in the same
  transaction, so it is never charged twice.
- `notices/{id}`: `title`, `body`, `important`, `status` (`draft` |
  `published` | `archived`), `publishedAt`. Students can read a notice only
  while it is published.
- `activity_logs/{id}`: audit trail; the app only ever adds entries. `type`, `message`,
  `entityId`, `entityName`, `actorId`, `actorName`, `createdAt`.
- `notifications/{id}`: `recipientId`, `title`, `body`, `read`, `createdAt`.

Bed allocation, transfer and exit run as Firestore transactions that re-read
the bed first, so a bed can never be given to two students.

### Fields the dashboard expects from later phases

- `fees/{id}.openDueDate`: the due date while a balance remains; removed when
  the fee is settled. Overdue = `openDueDate` before today.
- `hostel_stats/fees.outstanding` and `fee_summaries/{yyyy-MM}.collected`:
  running totals updated in the same write as each fee and payment.
- `leaves/{id}`: `status`, `fromDate`, `toDate`, and `approvedUntil` (set to
  `toDate` on approval only).
- `complaints/{id}.status`: `pending` | `assigned` | `in_progress` |
  `resolved`.
