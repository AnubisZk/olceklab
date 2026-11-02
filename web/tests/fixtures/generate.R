# Arayüz testleri için fikstürler: gerçek R motoru çıktıları (uydurma sayı yok).
# Depo kökünden: LANG=C.UTF-8 Rscript web/tests/fixtures/generate.R
engine <- normalizePath("engine")
for (f in sort(list.files(file.path(engine, "R"), pattern = "[.]R$", full.names = TRUE, recursive = TRUE))) source(f, encoding = "UTF-8")
out <- file.path("web", "tests", "fixtures")
write_fx <- function(x, name) writeLines(as.character(to_json(x)), file.path(out, name), useBytes = TRUE)

v <- load_example("bfi")
ds <- list(id = "fixture-bfi", data = v$data, hash = v$hash, filename = v$filename,
           source = list(type = "example", name = "bfi", label = v$source), suggested_config = v$suggested_config)
write_fx(dataset_overview(ds), "bfi_overview.json")
cfg <- build_config(ds$data, v$suggested_config)
cl <- analysis_clean(ds$data, cfg, list(), ds$hash)
write_fx(cl$record, "bfi_clean.json")
ds$config <- cfg; ds$clean <- cl$clean; ds$clean_rules <- list()
item <- analysis_item(cl$clean$data, cfg, list(), ds$hash, cl$clean$item_missing)
item$r_script <- build_r_script("item_analysis", ds, item$settings)
write_fx(item, "bfi_item.json")
fn <- analysis_factor_number(cl$clean$data, cfg, list(extraction = "both", reference = "resampled_bootstrap", n_iter = 50L, seed = 20261030L), ds$hash)
fn$r_script <- build_r_script("factor_number", ds, fn$settings, fn$seed)
write_fx(fn, "bfi_factor_number.json")
cat("fikstürler yazıldı:", paste(list.files(out, pattern = "json$"), collapse = ", "), "\n")
