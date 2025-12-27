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

```http
GET /students/{id}
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
  "currency": "EGP"
}
```

### Update Student

```http
PUT /students/{id}
Content-Type: application/json

{
  "name": "Updated Name",
  "payment_status": "تم الدفع"
}
```

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
    }
  ]
}
```

> **Note:** Postponed schedules are only returned if they are in the future.

### Get Student's Family Wallet

```http
GET /students/{id}/wallet
```

### Get Family Members

```http
GET /students/{id}/family
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

```http
GET /wallet/family/{family_id}
```

### Get Student's Wallet

```http
GET /wallet/student/{student_id}
```

### Get Transactions

```http
GET /wallet/family/{family_id}/transactions?page=1
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

### List Conversations

```http
GET /chat/conversations?page=1
```

### Get Messages

```http
GET /chat/conversations/{id}/messages?page=1
```

### Send Message

```http
POST /chat/conversations/{id}/messages
Content-Type: application/json

{
  "message": "مرحباً!"
}
```

### Create Conversation

```http
POST /chat/conversations
Content-Type: application/json

{
  "recipient_id": 123,
  "message": "السلام عليكم"
}
```

### Mark as Read

```http
POST /chat/conversations/{id}/read
```

### Unread Count

```http
GET /chat/unread-count
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

**API Version:** 2.0.1  
**Last Updated:** December 2024

### Recent Changes (v2.0.1)

- **Free Slots:** Now excludes/splits slots around scheduled postponed lessons
- **Student Schedules:** Returns both regular and future postponed schedules
- **Reports:** Students can create postponement reports for their own lessons
- **Postpone:** Students can create postponed events for their own schedules
- **Free Slots Response:** Added `day_of_week`, `start_time`, `end_time` format
