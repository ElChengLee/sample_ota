// Non-web: Mini App luôn chạy dưới dạng Flutter web, nên ở đây không có Shell.

bool get hasShell => false;

void postToShell(String message) {}

void listenFromShell(void Function(String raw) onMessage) {}
