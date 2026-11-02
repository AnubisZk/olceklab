# Tarayıcıda görünen metinleri bağımsız R hesabıyla karşılaştırır.
# Kullanım (depo kökünden): Rscript docs/test-logs/faz1/browser_crosscheck.R <browser_flow çıktısı.json>
engine <- normalizePath("engine")
for (f in sort(list.files(file.path(engine, "R"), pattern = "[.]R$", full.names = TRUE, recursive = TRUE))) source(f, encoding = "UTF-8")
ui <- jsonlite::fromJSON(commandArgs(TRUE)[1])
v <- load_example("bfi"); cfg <- build_config(v$data, v$suggested_config)
cl <- analysis_clean(v$data, cfg, list(), v$hash)
item <- analysis_item(cl$clean$data, cfg, list(), v$hash, cl$clean$item_missing)
fn <- analysis_factor_number(cl$clean$data, cfg, list(extraction = "pc", n_iter = 200L, seed = 20261030L), v$hash)
ref <- suppressMessages(suppressWarnings({ options(mc.cores = 1); RNGkind("Mersenne-Twister", "Inversion", "Rejection"); set.seed(20261030L)
  out <- NULL; utils::capture.output(out <- psych::fa.parallel(cl$clean$data[, cfg$items$name], fa = "pc", n.iter = 200, plot = FALSE)); out }))
chk <- function(lbl, ok) cat(sprintf("[%s] %s\n", if (isTRUE(ok)) "AYNI" else "FARKLI", lbl))
chk(sprintf("satır sayısı: arayüz %s, R %d", ui$n_rows, nrow(v$data)), ui$n_rows == as.character(nrow(v$data)))
chk("temizleme özeti metni", identical(ui$clean_summary, cl$record$results$summary_tr))
r1 <- item$tables[[1]]$rows_fmt$tr[1, ]
chk(sprintf("madde tablosu ilk satır (%s): r_drop %s, alpha_drop %s", r1$item, r1$r_drop, r1$alpha_drop),
    identical(ui$item_first_row[c(1, 7, 8)], c(r1$item, r1$r_drop, r1$alpha_drop)))
chk("karar metni (motor, aynı ayar ve tohum)", identical(ui$decision, fn$results$decision_tr))
chk(sprintf("önerilen bileşen: motor %d, psych::fa.parallel (doğrudan) %d", fn$results$pc$suggested, ref$ncomp), fn$results$pc$suggested == ref$ncomp)
p1 <- fn$tables[[1]]$rows_fmt$tr[1, ]
chk(sprintf("PA tablosu ilk satır: gözlenen %s, referans %%95 %s", p1$pc_obs, p1$pc_q), identical(ui$pa_first_row[c(2, 4)], c(p1$pc_obs, p1$pc_q)))
chk(sprintf("PA tablosu satır sayısı %d = madde sayısı %d", ui$pa_table_rows, length(cfg$items$name)), ui$pa_table_rows == length(cfg$items$name))
chk("ısı haritası ve scree SVG olarak çizildi", isTRUE(ui$item_heatmap_svg) && isTRUE(ui$scree_svg))
chk("masaüstü ve telefon genişliğinde yatay kaydırma yok", !isTRUE(ui$horizontal_scroll) && !isTRUE(ui$mobile_horizontal_scroll))
cat(sprintf("Paralel analiz süresi (tarayıcıdan, 200 yineleme, 25 madde, N = %d): %.1f sn\n", cl$clean$n_final, ui$pa_seconds))
