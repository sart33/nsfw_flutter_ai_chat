# Uncensored Flutter AI Roleplay Chat

**Description:** A fully local, privacy-first Flutter app for uncensored NSFW roleplay chats with AI.  
Uses your own DeepSeek API key for text generation (no built-in censorship) and Novita AI for image generation.  
Everything stored on-device: characters, chats, settings in SQLite; images in app documents folder. No servers, no tracking.

**Current Features:**
- Create/edit characters with detailed appearance descriptions
- Static NSFW gallery generation (20 random erotic poses/locations per character)
- Generate avatar from character description
- Basic chat interface (single persona for now)
- Secure storage for user-provided API keys (flutter_secure_storage)

**API Keys (required to use):**
Currently hardcoded placeholders in `lib/core/config/app_config.dart` (or similar file):  
Replace with your real keys:

```dart
// In lib/core/config/app_config.dart or services
const String deepSeekApiKey = 'YOUR_DEEPSEEK_API_KEY_HERE';
const String novitaApiKey = 'YOUR_NOVITA_API_KEY_HERE';
Get keys:

DeepSeek: https://platform.deepseek.com/api_keys
Novita AI: https://novita.ai/dashboard/api-keys

Note: This is early WIP. Image features won't work without valid keys.
Future plans: user input for keys in Settings screen, dynamic context-based generation, notifications.
Setup:

flutter pub get
Insert your API keys in the config file
flutter run

License: MIT