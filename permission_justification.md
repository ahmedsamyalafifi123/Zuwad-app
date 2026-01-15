# Google Play Permission Justification

## FOREGROUND_SERVICE_CONNECTED_DEVICE

### Description for Google Play:

**Usage**: The `FOREGROUND_SERVICE_CONNECTED_DEVICE` permission is required to maintain Bluetooth audio device connectivity during live video lessons when the app is running in Picture-in-Picture (PiP) mode or in the background.

**Video Demonstration Should Show**:

1. Student/Teacher joins a live video lesson using the "Join Lesson" button
2. User connects Bluetooth headphones/earbuds for audio during the lesson
3. User minimizes the app (presses home button) - the app enters PiP mode
4. While in PiP mode, the user opens another app (e.g., notepad, browser)
5. During this time, the Bluetooth audio connection remains active and the meeting audio continues playing
6. User can still hear the lesson audio through Bluetooth headphones while using other apps

**Core Use Case**: Zuwad is an educational platform for Quran lessons. During live 1-on-1 video lessons between teachers and students, users often use Bluetooth audio devices. The foreground service with connected device type ensures the Bluetooth connection is maintained when the app enters Picture-in-Picture mode, allowing students to take notes or use other apps while continuing to listen to their teacher.

---

## FOREGROUND_SERVICE_MICROPHONE

### Description for Google Play:

**Usage**: The `FOREGROUND_SERVICE_MICROPHONE` permission is required to continue capturing and transmitting microphone audio during live video lessons when the app is running in Picture-in-Picture (PiP) mode or in the background.

**Video Demonstration Should Show**:

1. Student/Teacher joins a live video lesson using the "Join Lesson" button
2. The meeting screen shows both student and teacher video feeds with active microphone
3. User minimizes the app (presses home button) - the app enters PiP mode showing the video
4. User opens another app while the lesson continues in PiP
5. The user speaks and the other participant in the lesson can still hear them (microphone remains active)
6. The live lesson audio/video continues without interruption in the PiP window

**Core Use Case**: Zuwad is an educational platform for live Quran lessons. Students and teachers conduct real-time 1-on-1 video lessons where continuous microphone access is essential. The foreground service with microphone type ensures the audio stream isn't interrupted when students/teachers briefly check other apps (for notes, schedules, etc.) while their lesson continues in a floating PiP window.

---

## Video Recording Script

### Steps to demonstrate both permissions:

1. **Open Zuwad App** → Show the main page with lessons list
2. **Navigate to a scheduled lesson** → Tap on "Join Lesson" (انضم للدرس) button
3. **Grant camera/microphone permissions** when prompted
4. **Show the active meeting** → Both video feeds visible, microphone active
5. **Connect Bluetooth audio** (if available) → Show the audio routing
6. **Press Home button** → App minimizes to Picture-in-Picture mode
7. **Open another app** (e.g., Notes app) → Write some notes
8. **Show PiP window** → The video lesson continues in the corner
9. **Speak into the phone** → Demonstrate microphone is still active (other party hears you)
10. **Listen to audio** → Demonstrate the lesson audio continues playing
11. **Tap PiP to return** → Back to full-screen meeting

### Key Points to Emphasize:

- This is an **educational app** for live tutoring
- PiP allows students to **take notes** while listening to lessons
- **Bluetooth connectivity** ensures users with wireless headphones have uninterrupted audio
- **Microphone access** ensures students can ask questions even while checking reference materials
