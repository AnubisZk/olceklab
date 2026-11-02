# Yalnızca §11.3 BİDEKÇET testlerini çalıştırır ve sonucu tabloya yazar.
#   cd engine
#   BIDEKCET_DATA_DIR=/veri/klasoru LANG=C.UTF-8 Rscript tests/private/run_bidekcet.R
# Çıktı: tests/private/bidekcet_sonuc.csv (depoya girmez; yalnızca toplu sonuçlar içerir).
if (!nzchar(Sys.getenv("BIDEKCET_DATA_DIR"))) stop("BIDEKCET_DATA_DIR ortam değişkenini veri klasörüne ayarlayın.")
if (!isTRUE(l10n_info()[["UTF-8"]])) stop("UTF-8 yerel ayarı gerekir: LANG=C.UTF-8")
out <- file.path(normalizePath("."), "tests", "private", "bidekcet_sonuc.csv")
Sys.setenv(BIDEKCET_REPORT = out)
res <- testthat::test_file(file.path("tests", "testthat", "test-private-bidekcet.R"), reporter = "summary",
                           load_helpers = TRUE, stop_on_failure = FALSE)
if (file.exists(out)) {
  tab <- utils::read.csv(out, fileEncoding = "UTF-8")
  print(tab, row.names = FALSE)
  cat(sprintf("\n%d/%d ölçüt AYNI. Ayrıntı: %s\n", sum(tab$sonuc == "AYNI"), nrow(tab), out))
}
cat("\nsessionInfo():\n"); print(utils::sessionInfo())
