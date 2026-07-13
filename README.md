# Uncensored Souls
 
Local-first Flutter app for uncensored 18+ AI character chat and storytelling. Bring your own API keys, pay the providers directly, keep everything on your device.
 
**Website & downloads:** https://sart33.github.io/uncensored-souls/
 
> **Internet required.** Chat and image generation run through the DeepSeek and Novita APIs. This is by design, not an optional online feature — the app cannot work offline. There are no developer-operated servers: requests go straight from your device to the providers.
 
---
 
## What it does
 
- **Unrestricted text chat** with AI characters. No content filtering on the roleplay itself.
- **Multi-character chat** — up to 5 characters at once. They talk to you *and* to each other: arguing, planning, reacting.
- **In-chat scene generation** — generate a photorealistic image of what is happening, mid-conversation. Location, pose, mood and actions are extracted from the scene automatically.
- **Three gallery modes** per character: Daily Life / Erotic / 18+, with consistent appearance across generations.
- **Your own persona in scenes** — optionally set age, ethnicity and hair colour, per character.
- **Character creation** with descriptions, avatars and behaviours. Two neutral starter characters are built in; an optional Starter Pack adds 12 more, ready to use.
- **Branch system** — multiple independent chat histories per character.
- Message editing, cascade deletion, regeneration.
- Personality drift protection and automatic summarization for long conversations.
- Adjustable temperature, font size, input/output length limits.
- Full export/import of all data, portable across platforms.
- Auto-delete for in-chat images (7–60 days). Generated images stay inside the app, never in the system gallery.
- Localised in 8 languages. The models understand 50+, so character descriptions can be written in your own language.
## Privacy
 
No accounts. No cloud storage. No analytics or telemetry. Characters, chats, images, settings and API keys stay on the device — SQLite for data, app documents directory for images, `flutter_secure_storage` for keys. Requests go directly to DeepSeek and Novita; the developer has no access to any of it.
 
## Pricing
 
Pay-as-you-go, straight to the providers, no markup and no subscription.
 
| | Required | Cost |
|---|---|---|
| DeepSeek (chat) | yes | ~$0.01 per hour of active use |
| Novita (images) | optional | ~$0.005 per image |
 
Heavy daily use with images lands around $2–4/month. Lighter use stays near $1. No message quotas, no session limits.
 
## Install
 
Prebuilt binaries: https://sart33.github.io/uncensored-souls/#download
 
- **Android** — install the APK.
- **Windows** — extract and run the `.exe`.
- **macOS** — open the `.dmg`. Unsigned, so allow it in System Settings → Privacy & Security.
On first launch you are taken to the API Keys screen. Enter your DeepSeek key to start chatting; add a Novita key only if you want images. Setup walkthrough: [User Guide → API keys](https://sart33.github.io/uncensored-souls/user-guide.html#api-keys)
 
Optionally import the Starter Pack via the in-app Import function.
 
### Building from source
 
```bash
flutter pub get
flutter run
```
 
No hardcoded keys anywhere — everything is entered through the in-app API Keys screen.
 
Get keys at [platform.deepseek.com](https://platform.deepseek.com/api_keys) and [novita.ai](https://novita.ai/user/register).
 
## Known limits
 
Image generation focuses on scene, mood and character presence. Current models do not render explicit sexual acts convincingly, so scene extraction deliberately avoids them — expect "before / after" framing rather than the act itself. Text chat has no such restriction.
 
**macOS** is an unsigned alpha at v1.2.0. Scene extraction is temporarily unavailable there; chat, character interaction, avatar generation and galleries all work.
 
## Content policy
 
All characters are adults. Age verification gates 18+ content, and a multi-stage filter blocks creation of underage or underage-looking characters in both chat and image generation.
 
## Status
 
v1.2.3 (Android, Windows) · v1.2.0 (macOS) · in active development
 
## License
 
MIT
