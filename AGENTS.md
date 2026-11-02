# AGENTS.md — Kodlama ajanı için çalışma kuralları

> Kaynak: SPEC.md, Bölüm 0 (v1.0, 2 Kasım 2026). Bu dosya SPEC.md ile birlikte güncellenir.

1. **Sayısal sonuçların tek kaynağı R motorudur.** Bütün istatistiksel hesaplar `engine/` altındaki R kodunda, aşağıda adı verilen R paketleriyle yapılır. JavaScript/TypeScript ve Python tarafında istatistik yeniden hesaplanmaz. Yapay zekâ modülü hiçbir sayı üretmez.
2. **Asla sonuç uydurma.** Bir fonksiyon hata verirse hatayı kullanıcıya göster. Örnek, sahte ya da yer tutucu sayı gösterme. Testlerde beklenen değerleri elle yazma; Bölüm 11'deki referans değerleri kullan ya da referans fonksiyonu doğrudan çağırarak üret.
3. **Aşamalı çalış.** Bölüm 12'deki faz sırasını izle. Her fazın kabul ölçütlerini sağlayan testler geçmeden bir sonraki faza geçme.
4. **Her değişiklikten sonra testleri çalıştır.** R için `testthat`, ön yüz için `vitest` ve uçtan uca testler için `playwright`.
5. **Bilmediğin bir dış API'yi varsayma.** EVREN API'sinin ayrıntıları (uç noktalar, kimlik doğrulama, model adları) bu belgede yoktur. Bağdaştırıcıyı yapılandırılabilir yaz, gerçek değerleri `.env` dosyasından oku ve belgelenmemiş alanları uydurma.
6. **Gizlilik varsayılandır.** Yüklenen veriler diske kalıcı yazılmaz (Bölüm 10).
7. **Arayüz dili Türkçedir**, İngilizce seçeneği vardır. Kod, değişken ve fonksiyon adları İngilizcedir.
8. Paket sürümlerini `renv.lock` ve `package-lock.json` ile sabitle. Kullandığın sürümleri `docs/VERSIONS.md` dosyasına yaz.
