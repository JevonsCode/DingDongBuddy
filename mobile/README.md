# DingDong Android companion

Flutter app that pairs with the DingDong desktop through the encrypted relay,
receives Agent reminders on two Android notification channels, and mirrors the
PWA's clipboard, send and Agent views. Design, decisions and test results:
[docs/product/android-companion.md](../docs/product/android-companion.md).

```bash
flutter test
flutter build apk --debug
node tool/fake_desktop_host.mjs --state /tmp/fake-host.json --seconds 300
```
