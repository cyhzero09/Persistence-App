# Daily Tracker App — Design Document

## Overview
A personal mobile app for daily check-in tracking, reminders, and journaling. Built with Flutter, local-first storage, with optional cloud sync for the future.

## Target Platform
- iOS & Android via Flutter
- Development in WSL with Flutter Web (`flutter run -d chrome`)
- iOS builds via Codemagic (free tier, 500 min/month)

## Tech Stack
- **Framework**: Flutter 3.27+
- **Language**: Dart
- **Storage**: SQLite (drift package)
- **State Management**: Riverpod
- **Notifications**: flutter_local_notifications

## Navigation
Bottom tab bar with 5 tabs: 首頁, 時間軸, 日記, 提醒, 設定

## Pages

### 1. Home — Daily Check-in (default view)
- Opens to today's date
- Calendar at top (month view), days with check-ins are marked
- Tapping a date shows that day's check-in list below
- Each check-in item: checkbox + category name
- Users tap checkbox directly to toggle completion
- After checking, an optional note can be added (e.g., "跑了5公里")
- Predefined categories: 運動, 閱讀, 喝水, 冥想 (user can add/edit/delete)
- Can backfill past dates
- FAB to add a new check-in item to today

### 2. Reminders
- List of all reminders (both linked to check-in categories and standalone)
- Add reminder: pick date/time, optional link to a check-in category, or free text
- Linked reminder: notification only, user still checks in manually
- Notification at scheduled time via local notifications
- Swipe to delete / toggle complete

### 3. Timeline
- Chronological feed of check-ins + diary entries mixed together
- Each entry shows: date, type (check-in / diary), content
- Pull to refresh / infinite scroll backward

### 4. Diary
- List all diary entries, showing date + content preview (first line)
- Tap to view full entry
- FAB to create a new standalone diary entry
- Diary entries can also be created inline from check-in (attached note)

### 5. Settings
- Manage check-in categories (add / edit / delete)
- Export data (JSON file)
- Import data (restore from JSON file)
- Future: Google sign-in & cloud sync placeholder

## Data Model

### CheckInCategory
- id (int, PK)
- name (String)
- emoji (String)
- isDefault (bool)

### CheckInRecord
- id (int, PK)
- categoryId (FK → CheckInCategory)
- date (Date)
- isCompleted (bool)
- note (String?, optional diary-like note)

### DiaryEntry
- id (int, PK)
- date (DateTime)
- content (String)
- checkInRecordId (int?, FK → CheckInRecord, nullable — null means standalone diary)

### Reminder
- id (int, PK)
- title (String)
- dateTime (DateTime)
- categoryId (int?, FK → CheckInCategory, nullable — null means standalone)
- isCompleted (bool)

## Future
- Google sign-in for cloud sync
- Sync data to Firebase / Supabase
- Export to PDF
- Dark mode

## Non-Goals (v1)
- No social features
- No multi-user
- No cloud sync (post-v1)
