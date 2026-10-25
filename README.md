# Sarthak Gupta — Portfolio

Personal portfolio for Sarthak Gupta, built with Flutter for the web.

Live: https://sarthakgupta2912.github.io/Sarthak_Portfolio_Website/

## Featured builds

- **Fridge Roulette** — kid-friendly Android app that turns one fridge photo into an on-device AI cooking challenge. Flutter, YOLO/FoodSeg103 detection, ML Kit label reading, and a Qwen2.5 0.5B model streamed locally with MediaPipe. No account, ads, or analytics. https://github.com/SarthakGupta2912/Fridge-Roulette
- **LIMS** — offline-first invoice, billing, and local shop-ordering app for Android and Windows. Local SQLite source of truth, QR-paired hotspot ordering, delta sync, and PDF invoices. https://github.com/SarthakGupta2912/LIMS
- **PathKosh** — AI skill-tree and roadmap app for Android, live on Google Play. Forge AI turns a goal into a personalized step-by-step roadmap with prerequisites, XP and progress tracking, in English or Hindi. https://play.google.com/store/apps/details?id=com.Sarthak.pathkosh

## Develop

```bash
flutter pub get
flutter run -d chrome
```

## Build & deploy

```bash
flutter build web --release --base-href /Sarthak_Portfolio_Website/
```

Publish the contents of `build/web` to the `build` branch, which serves the site.
