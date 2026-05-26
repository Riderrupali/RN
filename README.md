# Code Magic - Personal AI Friend

**Offline Android AI Assistant — English, Hindi & Marathi**

---

## Features
- 🎤 Voice commands (offline)
- 💬 Chat with AI friend
- 📚 Personal knowledge base — teach the app anything
- 📄 Upload text files from ChatGPT/Gemini to train it
- 📱 Screen OCR — reads what's on screen
- 🌐 English + Hindi + Marathi language support
- 👨👩🧒 Male / Female / Child voice
- 🔇 Mute button + voice mute command
- ⚡ 100% offline — no server needed

---

## GitHub → Codemagic Setup

### Step 1: GitHub वर push करा
```bash
git init
git add .
git commit -m "Initial commit - Code Magic App"
git remote add origin https://github.com/YOUR_USERNAME/code-magic-app.git
git push -u origin main
```

### Step 2: Codemagic वर connect करा
1. [codemagic.io](https://codemagic.io) वर जा
2. **Add application** → GitHub repo select करा
3. **codemagic.yaml** automatically detect होईल
4. **Start build** → APK मिळेल!

---

## Voice Commands
| Command | Action |
|---------|--------|
| "mute" / "बंद कर" | Voice बंद |
| "unmute" / "बोल" | Voice चालू |
| "save" / "शिक" | माहिती save करा |
| "read screen" / "screen वाच" | Screen OCR |

---

## How to Teach the App
1. **Chat मध्ये** — विचारा, माहित नसेल तर app विचारेल, तुम्ही सांगा
2. **File upload** — ChatGPT/Gemini मधून text copy करा, .txt save करा, upload करा
3. **Knowledge Base** — directly add करा

---

## Tech Stack
- Flutter 3.x (Dart)
- SQLite (sqflite)
- ML Kit OCR (offline)
- flutter_tts + speech_to_text
- flutter_overlay_window
