# Zuwad REST API v2 - Android Developer Guide

## 🚀 Quick Start

### Base URL

```
https://your-domain.com/wp-json/zuwad/v2/
```

### Check API Status

```http
GET /status
```

---

## 🔐 Authentication

All endpoints (except login) require JWT Bearer token authentication.

### Login

```http
POST /auth/login
Content-Type: application/json

{
  "phone": "01234567890",
  "password": "user_password",
  "role": "student"  // optional: student, teacher, supervisor
}
```

**Response:**

```json
{
  "success": true,
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "expires_in": 604800,
    "token_type": "Bearer",
    "user": {
      "id": 123,
      "name": "Ahmed Mohamed",
      "phone": "01234567890",
      "email": "ahmed@example.com",
      "role": "student",
      "m_id": "ST-001-123",
      "profile_image_url": "https://example.com/wp-content/uploads/2024/01/profile_123.jpg"
    }
  }
}
```

### Using the Token

Include in all requests:

```http
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

### Refresh Token

```http
POST /auth/refresh
Content-Type: application/json

{
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

### Verify Token

```http
GET /auth/verify
Authorization: Bearer {token}
```

### Logout

```http
POST /auth/logout
Authorization: Bearer {token}
```

### Change Password

```http
POST /auth/change-password
Authorization: Bearer {token}
Content-Type: application/json

{
  "current_password": "old_password",
  "new_password": "new_password"
}
```

---

## 📚 Response Format

### Success Response

```json
{
  "success": true,
  "data": { ... },
  "meta": {
    "page": 1,
    "per_page": 20,
    "total": 150,
    "total_pages": 8
  }
}
```

### Error Response

```json
{
  "success": false,
  "error": {
    "code": "invalid_credentials",
    "message": "Invalid phone number or password",
    "status": 401
  }
}
```

---

## 👨‍🎓 Students API

### List Students

```http
GET /students?page=1&per_page=20&search=ahmed&teacher_id=5
```

### Get Student

**Permission:** Authenticated users (students can access their own data or family members)

Students can access their own profile data as well as data of family members who share the same `payment_phone`. This enables the account switching feature in mobile apps.

**Access Rules:**

- ✅ Allow if user is accessing their own data (user_id matches)
- ✅ Allow if the requested student has the same `payment_phone` as the authenticated user (family member)
- ❌ Deny otherwise

```http
GET /students/{id}
Authorization: Bearer {token}
```

**Response:**

```json
{
  "success": true,
  "data": {
    "id": 123,
    "display_name": "Ahmed Mohamed",
    "phone": "01234567890",
    "email": "student@example.com",
    "country": "مصر",
    "gender": "ذكر",
    "age": 12,
    "teacher_id": 5,
    "teacher_name": "Teacher Name",
    "teacher_gender": "أنثى",
    "lessons_number": 8,
    "lesson_duration": 60,
    "amount": 500,
    "currency": "EGP",
    "payment_status": "في انتظار الدفع"
  }
}
```

### Create Student

```http
POST /students
Content-Type: application/json

{
  "name": "Ahmed Mohamed",
  "phone": "01234567890",
  "teacher_id": 5,
  "lessons_number": 4,
  "lesson_duration": 60,
  "payment_status": "في انتظار الدفع",
  "amount": 500,
  "currency": "EGP",
  "gender": "ذكر"
}
```

### Update Student

**Permission:** Authenticated users (students can update their own data)

Students can update their own profile data via the API. This enables mobile apps to allow students to modify their information.

```http
PUT /students/{id}
Authorization: Bearer {token}
Content-Type: application/json

{
  "display_name": "Updated Name",
  "phone": "01234567890",
  "payment_phone": "01234567890",
  "lessons_number": 8,
  "lesson_duration": 60,
  "amount": 500,
  "country": "مصر",
  "gender": "ذكر",
  "age": 12,
  "notes": "ملاحظات"
}
```

#### Available Fields

| Field               | Type    | Description                            |
| ------------------- | ------- | -------------------------------------- |
| `display_name`      | string  | Student's display name                 |
| `phone`             | string  | Student's phone number                 |
| `payment_phone`     | string  | Payment contact phone                  |
| `email`             | string  | Email address                          |
| `lessons_number`    | integer | Number of lessons in package           |
| `lesson_duration`   | integer | Duration of each lesson (minutes)      |
| `amount`            | float   | Package price                          |
| `currency`          | string  | Currency (EGP, OMR, etc.)              |
| `payment_status`    | string  | Payment status                         |
| `country`           | string  | Country                                |
| `gender`            | string  | Gender (ذكر/أنثى)                      |
| `age`               | integer | Age                                    |
| `dob`               | string  | Date of birth (YYYY-MM-DD format)      |
| `notes`             | string  | Notes                                  |
| `remaining_lessons` | integer | Number of remaining lessons in package |

#### Balance Calculation (Automatic)

When `lessons_number` or `lesson_duration` changes, the system **automatically calculates and adjusts** the family wallet's `pending_balance`:

**Calculation Formula:**

```
1. Get remaining lessons = old_lessons_number - sessions_completed
2. Calculate per-lesson price = old_amount / old_lessons_number
3. Calculate total credit = remaining_lessons × per_lesson_price
4. Calculate adjustment = total_credit - new_amount
5. Apply adjustment to pending_balance
```

**Example:**

```
Current: 8 lessons, 500 EGP, 4 sessions completed
New: 4 lessons, 250 EGP

Calculation:
- Remaining lessons = 8 - 4 = 4 lessons
- Per-lesson price = 500 / 8 = 62.50 EGP
- Total credit = 4 × 62.50 = 250 EGP
- Adjustment = 250 - 250 = 0 EGP (no change needed)

If new amount was 200 EGP:
- Adjustment = 250 - 200 = +50 EGP (added to pending_balance)
```

#### Transaction Recording

When a balance adjustment is made, a **transaction record** is created in the family wallet with:

- **Transaction Type:** `pending_adjustment`
- **Description:** `تعديل الرصيد المتبقي (API): إجمالي الحصص المتبقية (X) - سعر الباقة الجديدة (Y) = Z`
- **Reference Type:** `lesson_change_adjustment`

This transaction appears in **سجل المعاملات** (Transaction History) in the family wallet page.

#### Response

**Success Response (with balance adjustment):**

```json
{
  "success": true,
  "data": {
    "id": 123,
    "display_name": "Updated Name",
    "lessons_number": 8,
    "remaining_lessons": 4,
    "lesson_duration": 60,
    "amount": 500,
    ...
  },
  "meta": {
    "updated_fields": ["display_name", "lessons_number", "pending_balance_adjusted"]
  }
}
```

**Success Response (no balance adjustment needed):**

```json
{
  "success": true,
  "data": { ... },
  "meta": {
    "updated_fields": ["display_name", "phone"]
  }
}
```

> **Important Notes:**
>
> - The `pending_balance_adjusted` field in `updated_fields` indicates a wallet adjustment was made
> - Balance adjustments only happen when `lessons_number` or `lesson_duration` changes
> - The adjustment affects only `pending_balance`, not the main `balance`
> - A transaction record is created for audit purposes

### Delete Student

```http
DELETE /students/{id}
```

### Get Student Reports

```http
GET /students/{id}/reports?page=1&per_page=20
```

### Get Student Schedules

Returns both regular schedules and future postponed schedules for the student.

```http
GET /students/{id}/schedules
```

**Response:**

```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "student_id": 123,
      "teacher_id": 5,
      "teacher_name": "Ahmed",
      "lesson_duration": 60,
      "is_postponed": false,
      "is_recurring": true,
      "postponed_date": null,
      "postponed_time": null,
      "schedules": [{ "day": "الأحد", "hour": "2:00 PM" }],
      "real_student_id": null
    },
    {
      "id": 2,
      "student_id": 123,
      "teacher_id": 5,
      "teacher_name": "Ahmed",
      "lesson_duration": 60,
      "is_postponed": true,
      "is_recurring": false,
      "postponed_date": "2024-01-20",
      "postponed_time": "14:00",
      "schedules": [
        { "day": "السبت", "hour": "2:00 PM", "is_postponed": true }
      ],
      "real_student_id": 123
    },
    {
      "id": "trial_456",
      "lead_id": 456,
      "student_id": 123,
      "teacher_id": 8,
      "teacher_name": "Mohamed",
      "lesson_duration": 30,
      "is_postponed": false,
      "is_recurring": false,
      "is_trial": true,
      "trial_date": "2024-01-25",
      "trial_time": "3:00 PM",
      "trial_datetime": "2024-01-25 15:00:00",
      "schedules": [
        {
          "day": "الخميس",
          "hour": "3:00 PM",
          "is_trial": true,
          "trial_date": "2024-01-25"
        }
      ],
      "real_student_id": null
    }
  ]
}
```

> **Note:**
>
> - Postponed schedules are only returned if they are in the future.
> - **Trial lessons** (تجريبي) from CRM are included with `is_trial: true` flag. These are scheduled trial sessions from the leads management system.
> - Trial lessons have an `id` prefixed with `trial_` and include `lead_id`, `trial_date`, `trial_time`, and `trial_datetime` fields.

### Get Student's Family Wallet

```http
GET /students/{id}/wallet
```

### Get Family Members

Returns all family members (students sharing the same `payment_phone`).

```http
GET /students/{id}/family
Authorization: Bearer {token}
```

**Response:**

```json
{
  "success": true,
  "data": {
    "family_id": 123,
    "members": [
      {
        "id": 456,
        "name": "Ahmed Mohamed",
        "m_id": "ST-001-456",
        "is_current": true,
        "lessons_name": "تحفيظ قرآن",
        "profile_image_url": "https://example.com/uploads/profile_456.jpg",
        "payment_status": "تم الدفع"
      },
      {
        "id": 789,
        "name": "Sara Mohamed",
        "m_id": "ST-001-789",
        "is_current": false,
        "lessons_name": "تجويد",
        "profile_image_url": null,
        "payment_status": "في انتظار الدفع"
      }
    ]
  }
}
```

### Upload Student Profile Image

Upload a profile image for a student. Accepts JPEG, PNG, GIF, or WebP files (max 5MB).

```http
POST /students/{id}/upload-image
Content-Type: multipart/form-data

image: [file]
```

**Response:**

```json
{
  "success": true,
  "data": {
    "profile_image_url": "https://example.com/wp-content/uploads/2024/01/profile_123.jpg"
  }
}
```

### Delete Student Profile Image

```http
DELETE /students/{id}/profile-image
```

**Response:**

```json
{
  "success": true,
  "data": {
    "message": "Profile image deleted successfully"
  }
}
```

> **Note:** Students can upload/delete their own profile images. Supervisors, administrators, and accountants can manage any student's profile image.

### Update Student Trial Date

Updates the trial date for a student in the CRM system. Finds the CRM lead record by student's user_id and updates the trial_date field.

**Permission:** Authenticated users (students can update their own trial dates, teachers/supervisors can update their assigned students)

```http
PUT /students/{id}/trial
Authorization: Bearer {token}
Content-Type: application/json

{
  "trial_date": "2024-01-25T15:00",
  "teacher_id": 8,
  "lesson_duration": 30
}
```

#### Parameters

| Field             | Type    | Required | Description                                                |
| ----------------- | ------- | -------- | ---------------------------------------------------------- |
| `trial_date`      | string  | Yes      | New trial datetime (formats: `Y-m-d H:i:s` or `Y-m-dTH:i`) |
| `teacher_id`      | integer | No       | Optional: Update the trial teacher                         |
| `lesson_duration` | integer | No       | Optional: Update trial lesson duration (minutes)           |

**Response:**

```json
{
  "success": true,
  "data": {
    "lead_id": 456,
    "student_id": 123,
    "student_name": "Ahmed Mohamed",
    "trial_date": "2024-01-25 15:00:00",
    "teacher_id": 8,
    "teacher_name": "Mohamed Ahmed",
    "lesson_duration": 30,
    "updated_fields": ["trial_date", "teacher_id", "lesson_duration"]
  }
}
```

**Error Responses:**

| Code                 | Status | Description                                   |
| -------------------- | ------ | --------------------------------------------- |
| `student_not_found`  | 404    | Student with given ID/m_id not found          |
| `not_a_student`      | 400    | User exists but is not a student              |
| `lead_not_found`     | 404    | No CRM lead found for this student            |
| `invalid_trial_date` | 400    | Invalid datetime format                       |
| `invalid_teacher`    | 400    | Teacher ID does not exist or is not a teacher |

> **Note:** This endpoint looks up the CRM lead by the student's WordPress user_id, so you only need to provide the student ID (not the lead_id).

---

## 👨‍🏫 Teachers API

### List Teachers

```http
GET /teachers?page=1&per_page=20&supervisor_id=3
```

### Get Teacher

```http
GET /teachers/{id}
```

**Response:**

```json
{
  "success": true,
  "data": {
    "id": 5,
    "display_name": "أحمد محمد",
    "email": "ahmed@example.com",
    "phone": "01234567890",
    "gender": "ذكر",
    "supervisor_id": 3,
    "teacher_status": "نشط عدد كامل"
  }
}
```

### Create Teacher

```http
POST /teachers
Content-Type: application/json

{
  "display_name": "New Teacher",
  "phone": "01234567890",
  "email": "teacher@example.com",
  "supervisor_id": 3,
  "gender": "ذكر",
  "teacher_status": "نشط عدد كامل"
}
```

### Update Teacher

```http
PUT /teachers/{id}
Content-Type: application/json

{
  "display_name": "Updated Name",
  "phone": "01234567890",
  "gender": "ذكر",
  "teacher_status": "نشط نصف عدد"
}
```

### Get Teacher's Students

```http
GET /teachers/{id}/students
```

### Get Teacher Calendar

```http
GET /teachers/{id}/calendar?start_date=2024-01-01&end_date=2024-01-31
```

### Get Free Slots

Returns available free slots, excluding times that have postponed lessons scheduled.

```http
GET /teachers/{id}/free-slots
GET /teachers/{id}/free-slots?student_id=123
```

**Response (without student_id):**

```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "teacher_id": 5,
      "day_of_week": 0,
      "start_time": "14:00:00",
      "end_time": "18:00:00"
    }
  ]
}
```

**Response (with student_id):**

```json
{
  "success": true,
  "data": {
    "slots": [...],
    "lesson_duration": 45
  }
}
```

> **Note:** `day_of_week` uses 0=Sunday, 1=Monday, ..., 6=Saturday. Slots are automatically split around any scheduled postponed lessons.

### Add Free Slot

```http
POST /teachers/{id}/free-slots
Content-Type: application/json

{
  "day": "الأحد",
  "time": "14:00",
  "end_time": "18:00"
}
```

> **Note:** `day` can be an integer (0-6) or Arabic day name. `end_time` is optional (defaults to 1 hour after start).

### Delete Free Slot

```http
DELETE /teachers/{id}/free-slots/{slot_id}
```

### Get Teacher Statistics

```http
GET /teachers/{id}/statistics
```

### Upload Teacher Profile Image

Upload a profile image for a teacher. Accepts JPEG, PNG, GIF, or WebP files (max 5MB).

```http
POST /teachers/{id}/upload-image
Content-Type: multipart/form-data

image: [file]
```

**Response:**

```json
{
  "success": true,
  "data": {
    "profile_image_url": "https://example.com/wp-content/uploads/2024/01/profile_456.jpg"
  }
}
```

### Delete Teacher Profile Image

```http
DELETE /teachers/{id}/profile-image
```

**Response:**

```json
{
  "success": true,
  "data": {
    "message": "Profile image deleted successfully"
  }
}
```

> **Note:** Teachers can upload/delete their own profile images. Supervisors and administrators can manage any teacher's profile image.

---

## 📅 Schedules API

### List Schedules

```http
GET /schedules?student_id=123&teacher_id=5
```

### Create Schedule

```http
POST /schedules
Content-Type: application/json

{
  "student_id": 123,
  "teacher_id": 5,
  "lesson_duration": 60,
  "schedule": [
    {"day": "الأحد", "time": "14:00"},
    {"day": "الثلاثاء", "time": "16:00"}
  ]
}
```

### Check Conflicts

```http
POST /schedules/check-conflicts
Content-Type: application/json

{
  "teacher_id": 5,
  "schedule": [{"day": "الأحد", "time": "14:00"}],
  "lesson_duration": 60
}
```

### Create Postponed Event

**Permission:** Any authenticated user (students can only postpone their own schedules)

```http
POST /schedules/postpone
Content-Type: application/json

{
  "student_id": 123,
  "teacher_id": 5,
  "original_date": "2024-01-15",
  "original_time": "14:00",
  "new_date": "2024-01-17",
  "new_time": "14:00",
  "lesson_duration": 60
}
```

> **Note:** Students can only create postponed events for their own lessons.

---

## 📝 Reports API

### List Reports

```http
GET /reports?student_id=123&teacher_id=5&start_date=2024-01-01&end_date=2024-01-31
```

### Create Report

**Permission:** Any authenticated user (students can only create postponement reports for their own lessons)

```http
POST /reports
Content-Type: application/json

{
  "student_id": 123,
  "teacher_id": 5,
  "date": "2024-01-15",
  "time": "14:00",
  "attendance": "حضور",
  "lesson_duration": 60,
  "tasmii": "سورة البقرة",
  "tahfiz": "الآيات 1-20",
  "notes": "أداء ممتاز",
  "is_postponed": false
}
```

**Student Postponement Report:**

```json
{
  "student_id": 123,
  "teacher_id": 5,
  "date": "2024-01-15",
  "time": "14:00",
  "attendance": "تأجيل ولي أمر",
  "lesson_duration": 60,
  "is_postponed": true
}
```

> **Note:** Students can only create reports with postponement attendance types: `تأجيل ولي أمر`, `تأجيل`, `تأجيل طالب`

### Upload Report Image

```http
POST /reports/upload-image
Content-Type: multipart/form-data

image: [file]
report_id: 123
```

### Calculate Session Number

```http
GET /reports/session-number?student_id=123&attendance=حضور
```

**Response:**

```json
{
  "success": true,
  "data": {
    "session_number": 5,
    "lessons_number": 8,
    "is_last_session": false
  }
}
```

#### Session Number Calculation Logic

The session number is automatically calculated based on the attendance type:

**Incrementing Attendances** (session number increases):
| Attendance | Arabic Name | Description |
|------------|-------------|-------------|
| `حضور` | Attendance | Student attended |
| `غياب` | Absence | Student was absent |
| `تأجيل المعلم` | Teacher Delay | Teacher postponed |
| `تأجيل ولي أمر` | Parent Delay | Parent/Student postponed |

**Non-Incrementing Attendances** (session number = 0):
| Attendance | Arabic Name | Description |
|------------|-------------|-------------|
| `تعويض التأجيل` | Delay Compensation | Makeup for postponed lesson |
| `تعويض الغياب` | Absence Compensation | Makeup for absence |
| `تجريبي` | Trial | Trial lesson |
| `اجازة معلم` | Teacher Leave | Teacher holiday |

**Postponed Events:**
Reports created with `is_postponed: true` always have session_number = 0.

**Reset Logic:**
When session_number exceeds `lessons_number`, it resets to 1 (new package cycle).

**Example:**

```
Student has 8 lessons, last report had session_number = 4
→ Next حضور report = session_number 5
→ Next تعويض التأجيل report = session_number 0 (non-incrementing)
```

---

## 💰 Payments API

### List Payments

```http
GET /payments?payment_status=في انتظار الدفع&page=1
```

### Get Payment Details

```http
GET /payments/{student_id}
```

### Update Payment Status

```http
PUT /payments/{student_id}/status
Content-Type: application/json

{
  "payment_status": "تم الدفع"
}
```

### Update Reminder Settings

```http
PUT /payments/{student_id}/reminder
Content-Type: application/json

{
  "reminder": "كل أسبوع"
}
```

### Send WhatsApp Reminder

```http
POST /payments/{student_id}/send-reminder
Content-Type: application/json

{
  "message": "تذكير بموعد السداد..."
}
```

---

## 💼 Leads/CRM API

### List Leads

```http
GET /leads?status=lead&page=1
```

### Get Kanban Board

```http
GET /leads/board
```

**Response:**

```json
{
  "success": true,
  "data": {
    "columns": ["lead", "contacted", "trial", "negotiation", "converted", "rejected"],
    "leads": {
      "lead": [...],
      "contacted": [...],
      ...
    }
  }
}
```

### Create Lead

```http
POST /leads
Content-Type: application/json

{
  "name": "New Lead",
  "phone": "01234567890",
  "status": "lead",
  "platform": "Facebook",
  "courses": "تحفيظ"
}
```

### Update Lead Status (Drag & Drop)

```http
PUT /leads/{id}/status
Content-Type: application/json

{
  "status": "contacted"
}
```

### Convert Lead to Student

```http
POST /leads/{id}/convert
Content-Type: application/json

{
  "teacher_id": 5,
  "schedules": [
    {"day": "الأحد", "time": "14:00"}
  ]
}
```

---

## 👛 Wallet API

### Get Family Wallet

**Permission:** Authenticated users (students can access their own family's wallet)

```http
GET /wallet/family/{family_id}
```

**Response:**

```json
{
  "success": true,
  "data": {
    "family_id": 123,
    "balance": 500,
    "pending_balance": -50,
    "currency": "EGP",
    "last_updated": "2024-01-15 14:30:00",
    "members": [
      {
        "id": 456,
        "name": "Ahmed Mohamed",
        "m_id": "ST-001-456"
      }
    ]
  }
}
```

### Get Student's Wallet

```http
GET /wallet/student/{student_id}
```

**Response:**

```json
{
  "success": true,
  "data": {
    "family_id": 123,
    "balance": 500,
    "pending_balance": -50,
    "currency": "EGP",
    "last_updated": "2024-01-15 14:30:00",
    "members": [...]
  }
}
```

### Get Transactions

**Permission:** Authenticated users (students can view their own family's transactions)

```http
GET /wallet/family/{family_id}/transactions?page=1
```

**Response:**

```json
{
  "success": true,
  "data": [
    {
      "id": 101,
      "type": "deposit",
      "amount": 500,
      "balance_after": 500,
      "pending_balance_after": -50,
      "description": "إضافة رصيد",
      "student_id": null,
      "student_name": null,
      "created_at": "2024-01-15 14:30:00"
    }
  ],
  "meta": {
    "page": 1,
    "per_page": 50,
    "total": 1,
    "total_pages": 1
  }
}
```

### Add Balance

```http
POST /wallet/family/{family_id}/add
Content-Type: application/json

{
  "amount": 500,
  "description": "إضافة رصيد",
  "student_id": 123
}
```

### Deduct Balance

```http
POST /wallet/family/{family_id}/deduct
Content-Type: application/json

{
  "amount": 200,
  "description": "خصم حصة"
}
```

---

## 🚫 Suspended Students API

### List Suspended Students

```http
GET /suspended-students?page=1
```

### Get Analytics

```http
GET /suspended-students/analytics
```

### Reactivate Student

```http
POST /suspended-students/{id}/reactivate
Content-Type: application/json

{
  "payment_status": "في انتظار الدفع"
}
```

### Suspend Student

```http
POST /students/{id}/suspend
Content-Type: application/json

{
  "reason": "عدم السداد"
}
```

---

## 📊 Analytics API

### Dashboard Stats

```http
GET /analytics/dashboard
```

### Student Statistics

```http
GET /analytics/students?start_date=2024-01-01&end_date=2024-01-31
```

### Teacher Statistics

```http
GET /analytics/teachers?start_date=2024-01-01&end_date=2024-01-31
```

### Revenue Analytics

```http
GET /analytics/revenue?period=month
```

### Lesson Statistics

```http
GET /analytics/lessons?start_date=2024-01-01&end_date=2024-01-31
```

### Payment Status Breakdown

```http
GET /analytics/payment-status
```

---

## 🔔 Notifications API

### Admin Notifications

```http
GET /notifications?status=unread&page=1
```

### Mark as Read

```http
POST /notifications/{id}/read
```

### Mark All as Read

```http
POST /notifications/mark-all-read
```

### Get Unread Count

```http
GET /notifications/count
```

### Teacher Notifications

```http
GET /teacher/notifications?page=1
```

### Teacher Unread Count

```http
GET /teacher/notifications/count
```

---

## 💬 Chat API

### Date & Time Handling

All dates and times returned by the API are in **UTC**.
The format is `YYYY-MM-DD HH:MM:SS` (e.g., `2024-01-15 12:30:00` for 14:30 Cairo time).

**Flutter Handling Guide:**

Since the API returns UTC strings without the `Z` suffix, you **must** treat them as UTC.

```dart
DateTime parseApiDate(String dateString) {
  // 1. Append 'Z' or replace space with 'T' and append 'Z' to force UTC parsing
  // e.g. "2024-01-15 12:30:00" -> "2024-01-15T12:30:00Z"
  String isoString = dateString.replaceAll(' ', 'T') + 'Z';

  // 2. Parse as UTC
  DateTime utcDate = DateTime.parse(isoString);

  // 3. Convert to device local time for display
  return utcDate.toLocal();
}
```

The Chat API provides real-time messaging between users based on their roles:

| Role           | Can Chat With                        |
| -------------- | ------------------------------------ |
| **Student**    | Their assigned teacher + supervisor  |
| **Teacher**    | Their students + their supervisor    |
| **Supervisor** | Their teachers + students under them |

### Get Available Contacts

Returns list of users the authenticated user can chat with.

```http
GET /chat/contacts
Authorization: Bearer {token}
```

**Response:**

```json
{
  "success": true,
  "data": [
    {
      "id": 5,
      "name": "أحمد محمد",
      "role": "teacher",
      "relation": "teacher",
      "profile_image": "https://example.com/uploads/profile.jpg"
    },
    {
      "id": 10,
      "name": "محمد علي",
      "role": "supervisor",
      "relation": "supervisor",
      "profile_image": null
    }
  ]
}
```

### List Conversations

```http
GET /chat/conversations?page=1&per_page=50
Authorization: Bearer {token}
```

**Response:**

```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "other_user": {
        "id": 5,
        "name": "أحمد محمد",
        "role": "teacher",
        "profile_image": null
      },
      "last_message": "السلام عليكم",
      "last_message_at": "2024-01-15 14:30:00",
      "unread_count": 2,
      "updated_at": "2024-01-15 14:30:00"
    }
  ],
  "meta": {
    "page": 1,
    "per_page": 50,
    "total": 5,
    "total_pages": 1
  }
}
```

### Create Conversation (or Get Existing)

Creates a new conversation or returns existing one with the recipient.

```http
POST /chat/conversations
Authorization: Bearer {token}
Content-Type: application/json

{
  "recipient_id": 123,
  "message": "السلام عليكم"  // Optional initial message
}
```

**Response:**

```json
{
  "success": true,
  "data": {
    "id": 1,
    "is_new": true,
    "other_user": {
      "id": 123,
      "name": "أحمد محمد",
      "role": "teacher",
      "profile_image": null
    },
    "message": {
      "id": 10,
      "message": "السلام عليكم",
      "sender_id": 5,
      "is_mine": true,
      "is_read": false,
      "created_at": "2024-01-15 14:30:00"
    }
  }
}
```

### Get Messages

```http
GET /chat/conversations/{id}/messages?page=1&per_page=50
Authorization: Bearer {token}
```

**Real-time sync (get new messages only):**

```http
GET /chat/conversations/{id}/messages?after_id=100
Authorization: Bearer {token}
```

**Response:**

```json
{
  "success": true,
  "data": {
    "conversation_id": 1,
    "other_user": {
      "id": 123,
      "name": "أحمد محمد",
      "role": "teacher",
      "profile_image": null
    },
    "messages": [
      {
        "id": 10,
        "message": "السلام عليكم",
        "sender_id": 5,
        "is_mine": false,
        "is_read": true,
        "created_at": "2024-01-15 14:30:00"
      },
      {
        "id": 11,
        "message": "وعليكم السلام",
        "sender_id": 123,
        "is_mine": true,
        "is_read": false,
        "created_at": "2024-01-15 14:31:00"
      }
    ]
  },
  "meta": {
    "page": 1,
    "per_page": 50,
    "total": 2,
    "total_pages": 1
  }
}
```

### Send Message

```http
POST /chat/conversations/{id}/messages
Authorization: Bearer {token}
Content-Type: application/json

{
  "message": "مرحباً! كيف حالك؟"
}
```

**Response:**

```json
{
  "success": true,
  "data": {
    "id": 12,
    "conversation_id": 1,
    "message": "مرحباً! كيف حالك؟",
    "sender_id": 123,
    "is_mine": true,
    "is_read": false,
    "created_at": "2024-01-15 14:32:00"
  }
}
```

> **Push Notification:** When a message is sent, the recipient automatically receives a push notification with:
>
> - **Title (from supervisor):** `💬 رسالة جديدة من خدمة العملاء`
> - **Title (from teacher):** `💬 رسالة جديدة من [Sender Name]`
> - **Body:** Message content (truncated to 100 characters)
> - **Data Payload:** `type`, `conversation_id`, `sender_id`, `sender_name`

### Send Direct Message (Convenience)

Send message directly by recipient ID. Creates conversation if needed.

```http
POST /chat/send-direct
Authorization: Bearer {token}
Content-Type: application/json

{
  "recipient_id": 5,
  "message": "السلام عليكم"
}
```

**Response:**

```json
{
  "success": true,
  "data": {
    "id": 13,
    "conversation_id": 1,
    "recipient_id": 5,
    "message": "السلام عليكم",
    "is_mine": true,
    "is_read": false,
    "created_at": "2024-01-15 14:33:00"
  }
}
```

### Mark as Read

Mark all messages from other user as read.

```http
POST /chat/conversations/{id}/read
Authorization: Bearer {token}
```

**Response:**

```json
{
  "success": true,
  "data": {
    "marked_read": 5
  }
}
```

### Get Unread Count

```http
GET /chat/unread-count
Authorization: Bearer {token}
```

**Response:**

```json
{
  "success": true,
  "data": {
    "unread_count": 3
  }
}
```

### Flutter Implementation Guide

#### Message Read Status (✓ / ✓✓)

Messages have an `is_read` field:

- `is_read: false` → Show single check ✓ (sent)
- `is_read: true` → Show double check ✓✓ (read)

**Important Rules:**

1. Only the **receiver** can mark messages as read
2. Call `POST /chat/conversations/{id}/read` when user **opens** the conversation
3. Do NOT call markAsRead during polling - only when user actively views

#### Complete Flutter Service

```dart
class ChatService {
  final ApiClient _api;
  Timer? _pollTimer;
  int _lastMessageId = 0;
  int? _activeConversationId;

  // Get available contacts based on user role
  Future<List<Contact>> getContacts() async {
    final response = await _api.get('/chat/contacts');
    return (response['data'] as List)
        .map((c) => Contact.fromJson(c))
        .toList();
  }

  // Get all conversations with unread counts
  Future<List<Conversation>> getConversations() async {
    final response = await _api.get('/chat/conversations');
    return (response['data'] as List)
        .map((c) => Conversation.fromJson(c))
        .toList();
  }

  // Get or create conversation when user taps on contact
  Future<Conversation> openConversation(int recipientId) async {
    final response = await _api.post('/chat/conversations', {
      'recipient_id': recipientId,
    });
    final conv = Conversation.fromJson(response['data']);
    _activeConversationId = conv.id;
    return conv;
  }

  // Get all messages for a conversation
  Future<List<Message>> getMessages(int conversationId) async {
    final response = await _api.get(
      '/chat/conversations/$conversationId/messages'
    );
    final messages = (response['data']['messages'] as List)
        .map((m) => Message.fromJson(m))
        .toList();

    if (messages.isNotEmpty) {
      _lastMessageId = messages.last.id;
    }

    // Mark messages as read when user opens conversation
    await markAsRead(conversationId);

    return messages;
  }

  // Poll for NEW messages only (for real-time updates)
  Future<List<Message>> pollNewMessages(int conversationId) async {
    if (_lastMessageId == 0) return [];

    final response = await _api.get(
      '/chat/conversations/$conversationId/messages?after_id=$_lastMessageId'
    );

    final messages = (response['data']['messages'] as List)
        .map((m) => Message.fromJson(m))
        .toList();

    if (messages.isNotEmpty) {
      _lastMessageId = messages.last.id;

      // Only mark as read if conversation is active AND has incoming messages
      if (_activeConversationId == conversationId) {
        final hasIncoming = messages.any((m) => !m.isMine && !m.isRead);
        if (hasIncoming) {
          await markAsRead(conversationId);
        }
      }
    }

    return messages;
  }

  // Send message
  Future<Message> sendMessage(int conversationId, String text) async {
    final response = await _api.post(
      '/chat/conversations/$conversationId/messages',
      {'message': text}
    );
    final msg = Message.fromJson(response['data']);
    _lastMessageId = msg.id;
    return msg;
  }

  // Mark messages as read - ONLY call when user opens/views conversation
  Future<void> markAsRead(int conversationId) async {
    await _api.post('/chat/conversations/$conversationId/read');
  }

  // Get total unread count for badge
  Future<int> getUnreadCount() async {
    final response = await _api.get('/chat/unread-count');
    return response['data']['unread_count'] ?? 0;
  }

  // Start polling for real-time updates
  void startPolling(int conversationId, Function(List<Message>) onNewMessages) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(Duration(seconds: 2), (_) async {
      final messages = await pollNewMessages(conversationId);
      if (messages.isNotEmpty) {
        onNewMessages(messages);
      }
    });
  }

  // Stop polling when leaving conversation
  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _activeConversationId = null;
  }
}
```

#### Message Model

```dart
class Message {
  final int id;
  final String message;
  final int senderId;
  final bool isMine;
  final bool isRead;  // Use for ✓/✓✓ display
  final DateTime createdAt;

  // Show ✓ for sent, ✓✓ for read (only on outgoing messages)
  String get statusIcon {
    if (!isMine) return ''; // No icon for incoming
    return isRead ? '✓✓' : '✓';
  }

  // Blue color for read, gray for sent
  Color get statusColor {
    return isRead ? Colors.blue : Colors.grey;
  }
}
```

#### Chat Flow Best Practices

1. **Opening Conversation:**

   ```dart
   void onContactTap(Contact contact) async {
     final conv = await chatService.openConversation(contact.id);
     final messages = await chatService.getMessages(conv.id);
     // Messages are now marked as read
     chatService.startPolling(conv.id, onNewMessages);
   }
   ```

2. **Leaving Conversation:**

   ```dart
   void onBackPressed() {
     chatService.stopPolling();
     // Refresh conversation list to update unread counts
     loadConversations();
   }
   ```

3. **Displaying Unread Badge:**

   ```dart
   // In conversation list, show unread_count from API
   ListTile(
     title: Text(conv.otherUser.name),
     subtitle: Text(conv.lastMessage ?? ''),
     trailing: conv.unreadCount > 0
       ? Badge(label: '${conv.unreadCount}')
       : null,
   )
   ```

4. **Handling Chat Push Notifications:**

   When a message is sent, the recipient receives a push notification with the following payload:

   ```json
   {
     "type": "chat_message",
     "conversation_id": "123",
     "sender_id": "456",
     "sender_name": "أحمد محمد"
   }
   ```

   Handle incoming notifications in your app:

   ```dart
   void handleNotification(RemoteMessage message) {
     final data = message.data;

     if (data['type'] == 'chat_message') {
       final conversationId = int.parse(data['conversation_id']);
       final senderId = int.parse(data['sender_id']);
       final senderName = data['sender_name'];

       // If user taps notification, navigate to chat
       Navigator.push(context, MaterialPageRoute(
         builder: (_) => ChatScreen(conversationId: conversationId),
       ));
     }
   }
   ```

   > **Tip:** Use the `conversation_id` from the notification payload to directly open the correct conversation.

---

## 🔔 Student Notifications API

Student notifications system for receiving and managing in-app notifications.

### Notification Types

| Type           | Description                         |
| -------------- | ----------------------------------- |
| `report`       | New lesson report added             |
| `schedule`     | Schedule changes or postponements   |
| `payment`      | Payment reminders or status changes |
| `announcement` | General announcements               |
| `reminder`     | Lesson or event reminders           |
| `system`       | System notifications                |

### List Notifications

Get paginated notifications for the authenticated student.

```http
GET /student/notifications?page=1&per_page=50&status=unread&type=report
Authorization: Bearer {token}
```

**Query Parameters:**

| Parameter    | Type    | Default      | Description                                    |
| ------------ | ------- | ------------ | ---------------------------------------------- |
| `page`       | integer | 1            | Page number                                    |
| `per_page`   | integer | 50           | Items per page                                 |
| `status`     | string  | all          | Filter: `unread`, `read`, `all`                |
| `type`       | string  | -            | Filter by notification type                    |
| `student_id` | integer | current user | Optional student ID to fetch notifications for |

**Response:**

```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "title": "تقرير جديد",
      "message": "تم إضافة تقرير حصة جديد من المعلم أحمد",
      "type": "report",
      "data": {
        "report_id": 456,
        "teacher_id": 789
      },
      "is_read": false,
      "created_at": "2024-01-15 14:30:00",
      "read_at": null
    }
  ],
  "meta": {
    "page": 1,
    "per_page": 50,
    "total": 10,
    "total_pages": 1
  }
}
```

**Query Parameters:**

| Parameter | Type    | Default | Description |
| --------- | ------- | ------- | ----------- |
| `page`    | integer | 1       | Page number |

### GET /student/notifications

- **Description**: Get notifications for the authenticated student
- **Method**: `GET`
- **Route**: `/wp-json/zuwad/v2/student/notifications`
- **Parameters**:

| Name       | Type    | Required | Description                                                    |
| :--------- | :------ | :------- | :------------------------------------------------------------- |
| page       | integer | No       | Page number (default: 1)                                       |
| per_page   | integer | No       | Items per page (default: 50)                                   |
| type       | string  | No       | Filter by notification type                                    |
| status     | string  | No       | Filter by status (read, unread, all)                           |
| student_id | integer | No       | ID of student to fetch notifications for (for family accounts) |

- **Response**:

```json
{
  "success": true,
  "data": [
    {
      "id": 123,
      "title": "Lesson Report",
      "body": "Your lesson report is ready",
      "type": "report",
      "is_read": false,
      "data": {},
      "created_at": "2023-01-01 12:00:00"
    }
  ],
  "pagination": {
    "total": 100,
    "total_pages": 5,
    "current_page": 1,
    "per_page": 20
  }
}
```

## Device Management API

### POST /devices/register

- **Description**: Register a device token for push notifications
- **Method**: `POST`
- **Route**: `/wp-json/zuwad/v2/devices/register`
- **Authentication**: Required
- **Parameters**:

| Name         | Type   | Required | Description                                            |
| :----------- | :----- | :------- | :----------------------------------------------------- |
| device_token | string | Yes      | The FCM registration token                             |
| platform     | string | No       | Device platform (android, ios, web) - default: android |

- **Response**:

```json
{
  "success": true,
  "data": {
    "message": "Device registered successfully"
  }
}
```

### POST /devices/unregister

- **Description**: Unregister a device token
- **Method**: `POST`
- **Route**: `/wp-json/zuwad/v2/devices/unregister`
- **Authentication**: Required
- **Parameters**:

| Name         | Type   | Required | Description                          |
| :----------- | :----- | :------- | :----------------------------------- |
| device_token | string | Yes      | The FCM registration token to remove |

- **Response**:

```json
{
  "success": true,
  "data": {
    "message": "Device unregistered successfully"
  }
}
```

### Get Single Notification

```http
GET /student/notifications/{id}
Authorization: Bearer {token}
```

### Mark Notification as Read

```http
POST /student/notifications/{id}/read
Authorization: Bearer {token}
```

**Response:**

```json
{
  "success": true,
  "data": {
    "message": "Marked as read",
    "id": 1
  }
}
```

### Mark All as Read

```http
POST /student/notifications/mark-all-read
Authorization: Bearer {token}
```

**Response:**

```json
{
  "success": true,
  "data": {
    "message": "All notifications marked as read",
    "count": 5
  }
}
```

### Get Unread Count

```http
GET /student/notifications/count
Authorization: Bearer {token}
```

**Response:**

```json
{
  "success": true,
  "data": {
    "unread_count": 3
  }
}
```

### Flutter Implementation Example

```dart
class NotificationService {
  final Dio _dio;

  NotificationService(this._dio);

  // Get notifications with pagination
  Future<List<Notification>> getNotifications({
    int page = 1,
    int perPage = 50,
    String? status,
    String? type,
  }) async {
    final response = await _dio.get('/student/notifications', queryParameters: {
      'page': page,
      'per_page': perPage,
      if (status != null) 'status': status,
      if (type != null) 'type': type,
    });

    return (response.data['data'] as List)
        .map((json) => Notification.fromJson(json))
        .toList();
  }

  // Get unread count for badge
  Future<int> getUnreadCount() async {
    final response = await _dio.get('/student/notifications/count');
    return response.data['data']['unread_count'];
  }

  // Mark single notification as read
  Future<void> markAsRead(int id) async {
    await _dio.post('/student/notifications/$id/read');
  }

  // Mark all as read
  Future<void> markAllAsRead() async {
    await _dio.post('/student/notifications/mark-all-read');
  }
}

class Notification {
  final int id;
  final String title;
  final String message;
  final String type;
  final Map<String, dynamic>? data;
  final bool isRead;
  final DateTime createdAt;
  final DateTime? readAt;

  Notification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    this.data,
    required this.isRead,
    required this.createdAt,
    this.readAt,
  });

  factory Notification.fromJson(Map<String, dynamic> json) {
    return Notification(
      id: json['id'],
      title: json['title'],
      message: json['message'],
      type: json['type'],
      data: json['data'],
      isRead: json['is_read'],
      createdAt: DateTime.parse(json['created_at']),
      readAt: json['read_at'] != null ? DateTime.parse(json['read_at']) : null,
    );
  }
}
```

---

## 🏆 Competition API

### List Competitions

```http
GET /competitions?status=active
```

### Get Competition

```http
GET /competitions/{id}
```

### Create Competition

```http
POST /competitions
Content-Type: application/json

{
  "name": "مسابقة الحفظ",
  "start_date": "2024-01-01",
  "end_date": "2024-03-31",
  "description": "مسابقة حفظ جزء عم"
}
```

### Get Registered Students

```http
GET /competitions/{id}/students
```

### Register Student

```http
POST /competitions/{id}/register
Content-Type: application/json

{
  "student_id": 123,
  "starting_surah": "الناس",
  "target_surah": "الفيل"
}
```

### Get Leaderboard

```http
GET /competitions/{id}/leaderboard
```

### Submit Report

```http
POST /competitions/{id}/reports
Content-Type: application/json

{
  "student_id": 123,
  "pages_memorized": 2.5,
  "date": "2024-01-15",
  "notes": "حفظ ممتاز"
}
```

### Get Analytics

```http
GET /competitions/{id}/analytics
```

---

## 📋 Options API

### Payment Statuses

```http
GET /options/payment-statuses
```

### Currencies

```http
GET /options/currencies
```

### Countries

```http
GET /options/countries
```

### Courses

```http
GET /options/courses
```

### Attendance Types

```http
GET /options/attendance-types
```

### Lead Statuses

```http
GET /options/lead-statuses
```

### Platforms

```http
GET /options/platforms
```

### Teacher Classifications

```http
GET /options/teacher-classifications
```

### Teacher Statuses

```http
GET /options/teacher-statuses
```

### Rejection Reasons

```http
GET /options/rejection-reasons
```

### Session Counts

```http
GET /options/session-counts
```

### Evaluation Grades

```http
GET /options/evaluation-grades
```

### Days of Week

```http
GET /options/days
```

### List Supervisors

```http
GET /supervisors
```

### Clear Cache

```http
POST /cache/clear
```

---

## 📹 LiveKit Meeting Rooms

Video conferencing for lessons using LiveKit.

### Room Naming Convention

Each student-teacher pair has a **fixed, permanent room**. This ensures both parties always join the same room regardless of lesson timing.

**Room Name Format:**

```
room_student_{student_id}_teacher_{teacher_id}
```

**Example:**

```
room_student_123_teacher_456
```

### Generating Room Name

#### PHP (WordPress)

```php
function generate_room_name($student_id, $teacher_id) {
    return "room_student_{$student_id}_teacher_{$teacher_id}";
}
```

#### Dart (Flutter)

```dart
String generateRoomName(int studentId, int teacherId) {
  return 'room_student_${studentId}_teacher_$teacherId';
}
```

### Token Generation

Tokens are generated server-side using LiveKit API credentials.

**Request (Teacher/Student):**

```http
POST /wp-admin/admin-ajax.php
Content-Type: application/x-www-form-urlencoded

action=get_meeting_token&room_name=room_student_123_teacher_456&student_name=Student Name
```

**Request (KPI Observer - Stealth Mode):**

```http
POST /wp-admin/admin-ajax.php
Content-Type: application/x-www-form-urlencoded

action=get_meeting_token&room_name=room_student_123_teacher_456&student_name=Student Name&is_stealth_hidden=true
```

| Parameter           | Required | Type    | Description                                                       |
| ------------------- | -------- | ------- | ----------------------------------------------------------------- |
| `action`            | Yes      | string  | Must be `get_meeting_token`                                       |
| `room_name`         | Yes      | string  | Room name in format `room_student_{id}_teacher_{id}`              |
| `student_name`      | No       | string  | Student name for logging purposes                                 |
| `is_stealth_hidden` | No       | boolean | Set to `true` for KPI observation mode (hidden from participants) |

**Response:**

```json
{
  "success": true,
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIs...",
    "room_name": "room_student_123_teacher_456",
    "server_url": "wss://livekit.zuwad-academy.com",
    "participant_name": "Teacher Name",
    "participant_id": 456,
    "is_observer": false
  }
}
```

**Response (KPI Stealth Mode):**

```json
{
  "success": true,
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIs...",
    "room_name": "room_student_123_teacher_456",
    "server_url": "wss://livekit.zuwad-academy.com",
    "participant_name": "[HIDDEN_KPI]KPI User Name",
    "participant_id": 789,
    "is_observer": true
  }
}
```

> **Note:** When `is_stealth_hidden=true`, the participant name is prefixed with `[HIDDEN_KPI]`. The client-side JavaScript filters out participants with this prefix, making KPI observers invisible to teachers and students in the room.

### LiveKit Server

| Setting      | Value                             |
| ------------ | --------------------------------- |
| Server URL   | `wss://livekit.zuwad-academy.com` |
| Token Expiry | 6 hours                           |

### Important Notes

> [!IMPORTANT]
> Both the Flutter app and WordPress must use the **same room naming format** (`room_student_{id}_teacher_{id}`) to ensure teacher and student join the same room.

> [!TIP]
> The fixed room approach means:
>
> - No timing sync issues between teacher and student
> - Room persists across all lessons
> - Either party can join first

---

## ⚠️ Error Codes

| Code                  | HTTP Status | Description                      |
| --------------------- | ----------- | -------------------------------- |
| `missing_token`       | 401         | No authentication token provided |
| `invalid_token`       | 401         | Token is invalid or malformed    |
| `token_expired`       | 401         | Token has expired                |
| `invalid_credentials` | 401         | Wrong phone or password          |
| `forbidden`           | 403         | User doesn't have permission     |
| `not_found`           | 404         | Resource not found               |
| `validation_error`    | 400         | Invalid input data               |
| `rate_limit_exceeded` | 429         | Too many requests                |
| `server_error`        | 500         | Internal server error            |

---

## 📱 Android Implementation Tips

### 1. Token Storage

Store tokens securely using `EncryptedSharedPreferences`:

```kotlin
val masterKey = MasterKey.Builder(context)
    .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
    .build()

val sharedPrefs = EncryptedSharedPreferences.create(
    context,
    "zuwad_prefs",
    masterKey,
    EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
    EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
)
```

### 2. Retrofit Setup

```kotlin
val client = OkHttpClient.Builder()
    .addInterceptor { chain ->
        val token = getAccessToken()
        val request = chain.request().newBuilder()
            .addHeader("Authorization", "Bearer $token")
            .build()
        chain.proceed(request)
    }
    .build()
```

### 3. Token Refresh

Implement automatic token refresh on 401 errors:

```kotlin
class AuthInterceptor : Authenticator {
    override fun authenticate(route: Route?, response: Response): Request? {
        if (response.code == 401) {
            val newToken = refreshToken()
            return response.request.newBuilder()
                .header("Authorization", "Bearer $newToken")
                .build()
        }
        return null
    }
}
```

### 4. Offline Support

- Cache responses using Room database
- Queue failed requests for retry
- Sync when connection restored

---

## 📞 Support

For API issues, contact the development team with:

- Endpoint called
- Request body
- Full response
- User ID (if authenticated)

---

**API Version:** 2.0.3  
**Last Updated:** January 2026

### Recent Changes (v2.0.3)

#### Push Notifications Enhancements

**1. Wallet Payment Notifications**

When payment reminders are sent to families, push notifications are now triggered:

| Reminder Type  | Title           | Body                                      |
| -------------- | --------------- | ----------------------------------------- |
| التنبيه الاول  | تذكير بالدفع 💳 | حان وقت تسديد رسوم الإشتراك.              |
| التنبيه الثاني | تذكير بالدفع 💳 | حان وقت تسديد رسوم الإشتراك.              |
| التنبيه التالت | تذكير بالدفع 💳 | حان وقت تسديد رسوم الإشتراك.              |
| لم يتم الرد    | تنبيه هام ⚠️    | برجاء إضافة رصيد لنستكمل الحصص في موعدها. |

**Payload Data:**

```json
{
  "type": "payment_reminder" | "payment_warning",
  "family_id": "123",
  "reminder_type": "التنبيه الاول"
}
```

**2. Balance Added Notifications**

When balance is added to a family wallet:

| Event      | Title            | Body                                |
| ---------- | ---------------- | ----------------------------------- |
| إضافة رصيد | تم إضافة رصيد 💶 | شكرًا لك. 🤩 تم إضافة الرصيد بنجاح. |

**Payload Data:**

```json
{
  "type": "balance_added",
  "family_id": "123",
  "amount": "500",
  "currency": "EGP"
}
```

**3. Lesson Report Notifications (API)**

Reports created via REST API now send push notifications (same as AJAX):

| Attendance   | Title                | Body                                |
| ------------ | -------------------- | ----------------------------------- |
| حضور         | إنجاز جديد 🥳        | تم إضافة تقرير حصة {name}           |
| غياب         | تنبيه غياب ⚠️        | {name} لاحظنا غيابك اليوم...        |
| تجريبي       | 🎓 تقرير حصة تجريبية | صدر تقرير الحصة التجريبية لـ {name} |
| تأجيل المعلم | تغيير موعد 📅        | بسبب ظرف طارئ للمعلمة...            |
| اجازة معلم   | تنبيه جدول 📅        | المعلمة في إجازة...                 |
| Other        | 🥳 انجاز جديد        | تم إضافة تقرير حصة {name}           |

**Payload Data:**

```json
{
  "type": "lesson_report",
  "report_id": "456",
  "attendance": "حضور"
}
```

**4. WhatsApp Media Message Handling**

Media messages (images/PDFs) sent via WhatsApp no longer trigger generic "رسالة واتساب جديدة" notifications. This prevents duplicate notifications since report images are handled by the dedicated report notification system.

### Previous Changes (v2.0.2)

- **Student Notifications:** New `/student/notifications` endpoints for in-app notifications
- **Helper Functions:** Added `zuwad_send_student_notification()` for easy integration

### Previous Changes (v2.0.1)

- **Free Slots:** Now excludes/splits slots around scheduled postponed lessons
- **Student Schedules:** Returns both regular and future postponed schedules
- **Reports:** Students can create postponement reports for their own lessons
- **Postpone:** Students can create postponed events for their own schedules
- **Free Slots Response:** Added `day_of_week`, `start_time`, `end_time` format

---

## 📱 Client Implementation Details

### Meeting Page Features

**Component:** `MeetingPage`

- **Path:** `lib/features/meeting/presentation/pages/meeting_page.dart`
- **Purpose:** Handles video conferencing using LiveKit.

**Implementation Logic:**

1.  **Arguments:** Accepts `roomName`, `participantName`, `participantId`, `lessonName`, `teacherName`.
2.  **Permissions:** Checks and requests `camera` and `microphone` permissions using `permission_handler`.
3.  **Service:** Uses `LiveKitService` to manage the specialized connection.
    - **Token Generation:** Generates a JWT token locally on the client using `LiveKitConfig` secrets.
    - **Connection:** Connects to the LiveKit server with audio/video options.
4.  **UI Layout:**
    - **Grid View:** Displays participants in a responsive grid.
    - **Screen Share:** Prioritizes screen share stream if active.
    - **Control Bar:** Toggles camera/mic and handles leaving the meeting.

**Room Naming Standard:**

- Format: `room_student_{studentId}_teacher_{teacherId}`
- This ensures consistency between the Flutter app and WordPress backend.

### Settings Page Features

**Component:** `SettingsPage`

- **Path:** `lib/features/student_dashboard/presentation/pages/settings_page.dart`
- **Purpose:** Manages student profile, subscriptions, and family wallet.

**Data Flow:**
The page relies on `SettingsRepository` for all data operations.

| Feature            | Action              | API Endpoint Logic                                                                    |
| :----------------- | :------------------ | :------------------------------------------------------------------------------------ |
| **Load Profile**   | `_loadData`         | Calls `GET /students/{id}`                                                            |
| **Load Wallet**    | `_loadData`         | Calls `GET /students/{id}/wallet` then `GET /students/{id}/family` (for transactions) |
| **Load Family**    | `_loadData`         | Calls `GET /students/{id}/family`, then iterates `GET /students/{id}` for each member |
| **Update Profile** | `_savePersonalData` | Calls `PUT /students/{id}` with changed fields                                        |
| **Upload Image**   | `_pickImage`        | Calls `POST /students/{id}/upload-image`                                              |
| **Change Pass**    | `changePassword`    | Calls `POST /auth/change-password`                                                    |

**Key State Management:**

- Uses `SettingsRepository` to isolate API calls.
- Updates local state variables (`_student`, `_walletInfo`, `_familyMembers`) upon fetching.
- Handles loading and error states for each section.

---

## 🎉 Real-time Celebration Events (LiveKit)

This section details how to implement the celebration animations (Hearts, Confetti, etc.) in the Flutter app to match the web experience.

### Overview

Celebrations are broadcasted to all participants in the room using **LiveKit Data Channels**.

- **Transport**: `room.localParticipant.publishData(data, { reliable: true })`
- **Event**: `room.on(RoomEvent.DataReceived, ...)`
- **Encoding**: JSON string encoded as bytes (UTF-8).

### 1. Payload Structure

The data payload is a JSON object converted to a byte array.

```json
{
  "type": "celebration",
  "variant": "hearts"
}
```

**Supported Variants:**

- `"hearts"` (Default)
- `"confetti"`
- `"claps"`
- `"thumbs"`

### 2. Sending Celebrations (Flutter -> Web/Mobile)

When the user (e.g., Teacher) taps a celebration button in the Flutter app:

1.  **Construct JSON**: `{"type": "celebration", "variant": "hearts"}`
2.  **Encode**: Convert string to bytes (UTF-8).
3.  **Publish**: Use `publishData` with `reliable: true`.

#### Example (Flutter/Dart pseudo-code):

```dart
Future<void> sendCelebration(String variant) async {
  if (room.localParticipant == null) return;

  final data = jsonEncode({
    'type': 'celebration',
    'variant': variant,
  });

  // Send to all participants
  await room.localParticipant!.publishData(
    utf8.encode(data),
    reliable: true,
  );

  // OPTIONAL: Trigger local animation manually if you want the sender to see it too
  // (BUT web logic is "Recipient-Focused", so typically sender doesn't see it on themselves).
}
```

### 3. Receiving Celebrations (Web/Mobile -> Flutter)

Your app should listen for incoming data events.

#### Example (Flutter/Dart):

```dart
room.addListener(RoomEvent.dataReceived, (data, participant, kind, topic) {
  try {
    final String decoded = utf8.decode(data);
    final Map<String, dynamic> payload = jsonDecode(decoded);

    if (payload['type'] == 'celebration') {
      final String variant = payload['variant'];
      final String senderIdentity = participant?.identity ?? 'unknown';

      // Trigger your animation function
      showCelebrationAnimation(variant, senderIdentity);
    }
  } catch (e) {
    print('Error parsing celebration data: $e');
  }
});
```

### 4. Display Logic (The "Recipient-Focused" Rule)

To match the web behavior, follow these targeting rules:

- **Logic**: The animation should appear on **Everyone EXCEPT the Sender**.
  - **If I am the Sender (Me)**: I should see the animation on **everyone else's video tiles** (or screens), but **NOT** on my own video tile.
  - **If I am the Receiver**: I should see the animation on **MY own video tile** (and other participants), but **NOT** on the Sender's video tile.

**Practical Implementation for Mobile:**

- **Scenario A: Teacher (Mobile) sends to Student (Web/Mobile):**
  - Teacher sees hearts floating on the **Student's video**.
  - Student sees hearts floating on **Their Own video**.

- **Scenario B: Student (Mobile) receives from Teacher:**
  - Student sees hearts floating on **Their Own video** (because they are the recipient).

**Visual Style:**

- **Hearts/Thumbs/Claps**: Float from **Bottom to Top** of the video frame.
- **Confetti**: Falls from **Top to Bottom**.
