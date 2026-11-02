# tests/private — BİDEKÇET regresyon testleri (yalnızca yerelde)

SPEC §11.3'teki değerler KVKK kapsamındaki ham veriye dayanır. Veri depoya konmaz.

## Çalıştırma

```
cd engine
BIDEKCET_DATA_DIR=/veri/klasoru LANG=C.UTF-8 Rscript tests/private/run_bidekcet.R
```

- `BIDEKCET_DATA_DIR`: iki Excel dosyasının bulunduğu klasör. Dosyalar başlıklarına bakılarak bulunur
  (ortaokul: `sınıf` ve `M1–M13`; lise: `Sinif` ve `Madde1–Madde13`). Dosya adları depoda yazılı değildir.
- İsteğe bağlı: `BIDEKCET_ORTAOKUL_FILE`, `BIDEKCET_LISE_FILE` ile dosyalar açıkça verilebilir.
- Sonuç tablosu `tests/private/bidekcet_sonuc.csv` dosyasına yazılır (yalnızca toplu değerler; `.gitignore` ile dışlanır)
  ve ekrana basılır. Ardından `sessionInfo()` çıktısı gelir.
- Aynı testler `BIDEKCET_DATA_DIR` tanımlıyken `Rscript tests/testthat.R` ile de çalışır; tanımlı değilse atlanır.

## Düzeneğin kendisi nasıl doğrulanıyor?

`tests/testthat/test-bidekcet-harness.R` CI'da çalışır. Gerçek veriyle aynı düzende iki **sentetik** Excel dosyası
(`tests/testthat/fixtures/bidekcet_synthetic/`) üzerinde belge sahibinin referans betiğini
(`tests/reference/bidekcet_referans.R`) ve platformu çalıştırır; temizleme adımlarının, verinin, alfa, KMO,
paralel analiz, DFA χ², Δχ², HTMT ve WLSMV indekslerinin iki yolda birebir aynı olduğunu denetler.
