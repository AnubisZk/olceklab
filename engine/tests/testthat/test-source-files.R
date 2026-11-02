r_files <- sort(list.files(file.path(engine_dir, "R"), pattern = "[.]R$", full.names = TRUE, recursive = TRUE))

test_that("bütün R dosyaları geçerli UTF-8 ve eksiksiz ayrıştırılıyor", {
  expect_true(isTRUE(l10n_info()[["UTF-8"]]))
  for (f in r_files) {
    lines <- readLines(f, encoding = "UTF-8", warn = FALSE)
    expect_true(all(validUTF8(lines)), info = basename(f))
    expect_no_error(parse(f, encoding = "UTF-8"))
  }
})

test_that("yerel ayar denetimi dosyası salt ASCII ve ilk sırada yükleniyor", {
  guard <- file.path(engine_dir, "R", "00_locale.R")
  bytes <- readBin(guard, "raw", file.size(guard))
  expect_true(all(as.integer(bytes) < 128L))
  expect_identical(basename(r_files[1]), "00_locale.R")
})

test_that("C yerel ayarında motor açık bir hatayla durur", {
  out <- callr::r(function(f) tryCatch({ source(f); "yüklendi" }, error = function(e) conditionMessage(e)),
                  args = list(f = file.path(engine_dir, "R", "00_locale.R")),
                  env = c(callr::rcmd_safe_env(), LANG = "C", LC_ALL = "C"))
  expect_match(out, "requires a UTF-8 locale", fixed = TRUE)
})
