// Tarayıcı depolaması yalnızca tercihler içindir (tema, dil). Erişim bazı
// ortamlarda (gizli pencere, engellenmiş site verisi) hata fırlatabilir.

export function readPreference(key: string): string | null {
  try {
    return window.localStorage.getItem(key);
  } catch {
    return null;
  }
}

export function writePreference(key: string, value: string): void {
  try {
    window.localStorage.setItem(key, value);
  } catch {
    // tercih kaydedilemezse arayüz yine çalışır
  }
}
