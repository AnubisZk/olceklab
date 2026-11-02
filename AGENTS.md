# AGENTS.md — Kodlama ajanı için çalışma kuralları

> Kaynak: SPEC.md, Bölüm 0 (v1.1, 2 Kasım 2026). Bu dosya SPEC.md ile birlikte güncellenir.

1. **Sayısal sonuçların tek kaynağı R motorudur.** Bütün istatistiksel hesaplar `engine/` altındaki R kodunda, aşağıda adı verilen R paketleriyle yapılır. JavaScript/TypeScript ve Python tarafında istatistik yeniden hesaplanmaz. Yapay zekâ modülü hiçbir sayı üretmez.
2. **Asla sonuç uydurma.** Bir fonksiyon hata verirse hatayı kullanıcıya göster. Örnek, sahte ya da yer tutucu sayı gösterme. Testlerde beklenen değerleri elle yazma; Bölüm 11'deki referans değerleri kullan ya da referans fonksiyonu doğrudan çağırarak üret.
3. **Aşamalı çalış.** Bölüm 12'deki faz sırasını izle. Her fazın kabul ölçütlerini sağlayan testler geçmeden bir sonraki faza geçme.
4. **Her değişiklikten sonra testleri çalıştır.** R için `testthat`, ön yüz için `vitest` ve uçtan uca testler için `playwright`.
5. **Bilmediğin bir dış API'yi varsayma.** EVREN API'sinin ayrıntıları (uç noktalar, kimlik doğrulama, model adları) bu belgede yoktur. Bağdaştırıcıyı yapılandırılabilir yaz, gerçek değerleri `.env` dosyasından oku ve belgelenmemiş alanları uydurma.
6. **Gizlilik varsayılandır.** Yüklenen veriler diske kalıcı yazılmaz (Bölüm 10).
7. **Arayüz dili Türkçedir**, İngilizce seçeneği vardır. Kod, değişken ve fonksiyon adları İngilizcedir.
8. Paket sürümlerini `renv.lock` ve `package-lock.json` ile sabitle. Kullandığın sürümleri `docs/VERSIONS.md` dosyasına yaz.
9. **Rastgelelik açıkça yönetilir.** Rastgele sayı kullanan her çağrıdan önce `RNGkind("Mersenne-Twister", "Inversion", "Rejection")` ve `set.seed()` ayarlanır. psych fonksiyonları `options(mc.cores = 1)` ile çağrılır. Tohum, RNG türü ve çekirdek ayarı analiz kaydına yazılır. (v1.1: PA-1, BS-2, EFA-2, MC-5)
10. **Sayılar yuvarlanmadan taşınır, biçimlenmiş hâlleri R'de üretilir.** JSON'da sayılar 17 anlamlı basamakla yazılır. Ekranda ve raporda görünen metin hâli R tarafından üretilir; ön yüz sayı yuvarlamaz ve biçimlendirmez. (v1.1: REP-3, REP-6)
11. **Motor UTF-8 yerel ayarında çalışır.** Aksi hâlde açık bir hatayla durur. (v1.1: ARCH-8)
