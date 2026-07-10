# Uncensored Flutter AI Roleplay Chat

A fully local, privacy-first Flutter app for uncensored NSFW roleplay
chats with AI. Uses your own API keys for text and image generation.
Everything stored on-device. No servers, no tracking.

## Features

- Create/edit characters with detailed descriptions and avatars
- Generate avatar from character description via Novita AI
- Static gallery: up to 20 generated images per character (random poses/locations)
- Single and multi-character chat modes
- Branch system: multiple independent chat histories per character
- Message editing, deletion (cascade), and regeneration
- Persistent chat history (SQLite)
- Character personality reminder system (anti-drift)
- Dark theme, adjustable font size and generation parameters
- Secure API key storage (flutter_secure_storage)

## Setup

1. `flutter pub get`
2. Run the app — on first launch you will be redirected to the API Keys screen
3. Enter your API keys there (stored securely on device, never transmitted)
4. Start chatting

## API Keys

- **DeepSeek** (required for chat): https://platform.deepseek.com/api_keys
- **Novita AI** (required for image generation): https://novita.ai/user/register

No hardcoded keys — everything entered through the in-app API Keys screen.

## Status

Early WIP. Core chat and image generation work.
Active development.

## License

MIT