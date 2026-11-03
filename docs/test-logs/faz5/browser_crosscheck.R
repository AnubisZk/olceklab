# Faz 5: tarayıcıdan indirilen Word raporunun (python-docx ile okunan) tablo hücreleri ve şablon cümleleri,
# CSV dosyaları ve proje içe aktarma sonuçları ↔ bağımsız R hesabı (lavaan/psych/semTools doğrudan; biçimleme sprintf ile).
# Kullanım: Rscript browser_crosscheck.R browser_flow_output.json
suppressPackageStartupMessages({library(lavaan); library(jsonlite)}); options(width = 250)
ui <- fromJSON(commandArgs(TRUE)[1], simplifyVector = FALSE)
f <- function(x, d = 3, bounded = TRUE) {
  s <- sprintf(paste0("%.", d, "f"), abs(x)); if (bounded) s <- sub("^0\\.", ".", s); s <- sub(".", ",", s, fixed = TRUE)
  if (x < 0 && grepl("[1-9]", s)) s <- paste0("−", s); s
}
ci <- function(a, b, d = 3, bounded = TRUE) sprintf("[%s; %s]", f(a, d, bounded), f(b, d, bounded))
res <- list(); chk <- function(w, a, b) res[[length(res) + 1L]] <<- data.frame(olcut = w, arayuz = a, bagimsiz_R = b, sonuc = if (identical(a, b)) "AYNI" else "FARKLI")
hs <- HolzingerSwineford1939; hs$school <- as.character(hs$school)
m <- "visual =~ x1 + x2 + x3\ntextual =~ x4 + x5 + x6\nspeed =~ x7 + x8 + x9"
fit <- cfa(m, data = hs)
fm <- fitMeasures(fit)
tab <- function(i) ui$docx_tables[[i]]
kv <- function(t, label) { for (r in t[-1]) if (identical(r[[1]], label)) return(r[[2]]); NA_character_ }
# --- Word: DFA uyum tablosu (Tablo 1) ---
t1 <- tab(1)
chk("docx DFA χ²", kv(t1, "χ²"), f(fm[["chisq"]], 3, FALSE))
chk("docx DFA sd", kv(t1, "sd"), sprintf("%d", as.integer(fm[["df"]])))
chk("docx DFA CFI", kv(t1, "CFI"), f(fm[["cfi"]]))
chk("docx DFA TLI", kv(t1, "TLI"), f(fm[["tli"]], 3, FALSE))
chk("docx DFA RMSEA", kv(t1, "RMSEA"), f(fm[["rmsea"]]))
chk("docx DFA RMSEA GA", kv(t1, "RMSEA %90 GA"), ci(fm[["rmsea.ci.lower"]], fm[["rmsea.ci.upper"]]))
chk("docx DFA SRMR", kv(t1, "SRMR"), f(fm[["srmr"]]))
# --- Word: standardize yükler (Tablo 2) ---
ss <- standardizedSolution(fit); ld <- ss[ss$op == "=~", ]
t2 <- tab(2)
for (k in c(1, 4, 9)) chk(sprintf("docx β %s", ld$rhs[k]), t2[[k + 1]][[7]], f(ld$est.std[k]))
# --- Word: şablon cümlesi ---
sent <- Filter(function(p) startsWith(p, "Modelin uyum değerleri"), ui$docx_paragraphs)[[1]]
exp_sent <- sprintf("Modelin uyum değerleri: χ²(%d) = %s, p < ,001; CFI = %s; TLI = %s; RMSEA = %s, %%90 GA %s; SRMR = %s (Tablo 1).",
                    as.integer(fm[["df"]]), f(fm[["chisq"]], 3, FALSE), f(fm[["cfi"]]), f(fm[["tli"]], 3, FALSE), f(fm[["rmsea"]]),
                    ci(fm[["rmsea.ci.lower"]], fm[["rmsea.ci.upper"]]), f(fm[["srmr"]]))
chk("docx DFA bulgu cümlesi", sent, exp_sent)
ld_sent <- Filter(function(p) startsWith(p, "Standardize faktör yükleri"), ui$docx_paragraphs)[[1]]
chk("docx yük aralığı cümlesi", ld_sent, sprintf("Standardize faktör yükleri %s ile %s arasında değişti (Tablo 2).", f(min(ld$est.std)), f(max(ld$est.std))))
# --- Word: güvenirlik (Tablo 5) ---
t5 <- tab(5); om <- semTools::compRelSEM(fit); av <- semTools::AVE(fit)
facs <- list(visual = c("x1", "x2", "x3"), textual = c("x4", "x5", "x6"), speed = c("x7", "x8", "x9"))
for (j in seq_along(facs)) {
  fn <- names(facs)[j]; row <- t5[[j + 1]]
  a <- suppressMessages(psych::alpha(hs[, facs[[j]]], warnings = FALSE))$total$raw_alpha
  chk(sprintf("docx α %s", fn), row[[3]], f(a)); chk(sprintf("docx ω %s", fn), row[[4]], f(om[[fn]])); chk(sprintf("docx AVE %s", fn), row[[5]], f(av[[fn]]))
}
h <- semTools::htmt(m, data = hs, htmt2 = FALSE, absolute = TRUE)
hm <- max(h[lower.tri(h)]); k <- which(h == hm & lower.tri(h), arr.ind = TRUE)[1, ]
ht <- Filter(function(p) startsWith(p, "En büyük HTMT"), ui$docx_paragraphs)[[1]]
chk("docx HTMT cümlesi", ht, sprintf("En büyük HTMT oranı %s (%s – %s) oldu (Tablo 6).", f(hm, 3, FALSE), rownames(h)[k[1]], colnames(h)[k[2]]))
# --- Word ve CSV: değişmezlik karşılaştırmaları (Tablo 9) ---
g <- function(eq = NULL) { a <- list(m, data = hs, group = "school", group.label = c("Pasteur", "Grant-White"), std.lv = TRUE); if (length(eq)) a$group.equal <- eq; do.call(cfa, a) }
cf <- g(); me <- g("loadings"); sc <- g(c("loadings", "intercepts"))
l1 <- lavTestLRT(cf, me); l2 <- lavTestLRT(me, sc)
t9 <- tab(9)
chk("docx metrik Δχ²", t9[[2]][[3]], f(l1[2, "Chisq diff"], 2, FALSE))
chk("docx skaler Δχ²", t9[[3]][[3]], f(l2[2, "Chisq diff"], 2, FALSE))
chk("docx skaler ΔCFI", t9[[3]][[7]], f(fitMeasures(sc, "cfi")[[1]] - fitMeasures(me, "cfi")[[1]]))
csvf <- utils::read.csv(text = ui$csv_formatted, sep = ";", check.names = FALSE, colClasses = "character")
csvr <- utils::read.csv(text = ui$csv_raw, check.names = FALSE)
chk("CSV biçimli metrik Δχ²", csvf[1, "Δχ²"], f(l1[2, "Chisq diff"], 2, FALSE))
chk("CSV ham metrik Δχ² (17 basamak)", sprintf("%.17g", csvr[1, "Δχ²"]), sprintf("%.17g", l1[2, "Chisq diff"]))
chk("CSV ham skaler p (17 basamak)", sprintf("%.17g", csvr[2, "p"]), sprintf("%.17g", l2[2, "Pr(>Chisq)"]))
chk("CSV ham metrik ΔCFI (17 basamak)", sprintf("%.17g", csvr[1, "ΔCFI"]), sprintf("%.17g", fitMeasures(me, "cfi")[[1]] - fitMeasures(cf, "cfi")[[1]]))
# --- Word yapısı ---
nums <- vapply(Filter(function(p) grepl("^Tablo [0-9]+$", p), ui$docx_paragraphs), function(p) as.integer(sub("Tablo ", "", p)), 0L)
chk("docx tablo numaraları ardışık", paste(nums, collapse = ","), paste(seq_along(ui$docx_tables), collapse = ","))
chk("docx yapay zekâ beyanı", as.character(any(grepl("yapay zekâ kullanılmamıştır", ui$docx_paragraphs, fixed = TRUE))), "TRUE")
chk("docx kaynakça: lavaan citation()", as.character(any(startsWith(unlist(ui$docx_paragraphs), "Rosseel"))), "TRUE")
# --- Proje içe aktarma ---
st <- function(r) paste(vapply(r, `[[`, "", 2L), collapse = ",")
chk("proje A (örnek veri) durumları", st(ui$importA_result), paste(rep("Aynı", length(ui$importA_result)), collapse = ","))
chk("proje A özet satırı", ui$importA_status, "Bütün sonuçlar 17 anlamlı basamakta aynı.")
chk("proje B (yüklenen veri, onaylı) durumları", st(ui$importB_result), paste(rep("Aynı", length(ui$importB_result)), collapse = ","))
chk("proje B veri baytları özgün dosyayla aynı", as.character(ui$zipB_data_identical), "TRUE")
chk("onaysız veri eklenemez (düğme devre dışı)", as.character(ui$export_disabled_without_consent), "TRUE")
chk("örnek veride proje dosyasında data/ yok", as.character(!any(startsWith(unlist(ui$zipA), "data/"))), "TRUE")
chk("geri yüklenen oturumda DFA T1", toJSON(ui$restored_cfa_T1), toJSON(ui$ui_cfa_T1))
tb <- do.call(rbind, res); print(tb, row.names = FALSE)
cat(sprintf("\n%d/%d AYNI; önizlemede italik parça: %s; mobil yatay kaydırma: %s\n", sum(tb$sonuc == "AYNI"), nrow(tb), ui$preview_em, ui$mobile_horizontal_scroll))
