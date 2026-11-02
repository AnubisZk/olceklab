# tests/private — BİDEKÇET regresyon testleri (yalnızca yerelde)

SPEC §11.3'teki değerler KVKK kapsamındaki ham veriye dayanır. Veri depoya konmaz.

- Veri dosyaları `tests/private/data/` altına konur. Bu klasör `.gitignore` ile dışlanmıştır.
- Testler ilgili fazda (Faz 1–3) yazılacak ve veri yoksa `skip()` ile atlanacak.
- Sonuçlar, tarih ve sürüm bilgisiyle `docs/VALIDATION.md` dosyasına işlenecek.
