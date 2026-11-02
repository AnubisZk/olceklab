# Faz 2: tarayıcıda görünen metinler ↔ bağımsız R hesabı (lavaan, psych, semTools doğrudan çağrılır;
# biçimleme motorun fmt_* fonksiyonları kullanılmadan, sprintf ile ayrıca yapılır).
# Kullanım: LANG=C.UTF-8 Rscript browser_crosscheck.R browser_flow_output.json
suppressPackageStartupMessages({library(lavaan); library(semTools); library(psych); library(jsonlite)})
ui <- fromJSON(commandArgs(TRUE)[1], simplifyVector = FALSE)
f <- function(x, d = 3, bounded = TRUE) {
  s <- sprintf(paste0("%.", d, "f"), abs(x))
  if (bounded) s <- sub("^0\\.", ".", s)
  s <- sub(".", ",", s, fixed = TRUE)
  if (x < 0 && grepl("[1-9]", s)) s <- paste0("−", s)
  s
}
res <- list()
chk <- function(what, ui_text, ref_text) res[[length(res) + 1L]] <<- data.frame(olcut = what, arayuz = ui_text, bagimsiz_R = ref_text,
                                                                               sonuc = if (identical(ui_text, ref_text)) "AYNI" else "FARKLI")
hs <- HolzingerSwineford1939[, paste0("x", 1:9)]
# AFA
options(mc.cores = 1); RNGkind("Mersenne-Twister", "Inversion", "Rejection"); set.seed(20261030)
fa3 <- fa(hs, nfactors = 3, fm = "minres", rotate = "oblimin", cor = "cor", n.rotations = 20, scores = "none")
L <- unclass(fa3$loadings)
hdr <- unlist(ui$efa_header)
chk("AFA faktör sütunları", paste(hdr[2:4], collapse = " "), paste(colnames(L), collapse = " "))
for (i in c(1, 5, 9)) for (j in 1:3) chk(sprintf("AFA yük %s %s", rownames(L)[i], colnames(L)[j]), ui$efa_rows[[i]][[j + 1]], f(L[i, j]))
chk("AFA h² x9", ui$efa_rows[[9]][[5]], f(fa3$communality[["x9"]]))
chk("AFA χ²", ui$efa_fit[[2]][[2]], f(fa3$STATISTIC, 2, FALSE))
chk("AFA RMSEA %90 GA", ui$efa_fit[[7]][[2]], sprintf("[%s; %s]", f(fa3$RMSEA[["lower"]]), f(fa3$RMSEA[["upper"]])))
# DFA (ML, Wishart, Bollen–Stine B = 200, iseed = 20261030)
m3 <- "visual =~ x1 + x2 + x3\ntextual =~ x4 + x5 + x6\nspeed =~ x7 + x8 + x9"
set.seed(20261030)
fit <- suppressWarnings(cfa(m3, hs, estimator = "ML", likelihood = "wishart", std.lv = FALSE, test = "bollen.stine",
                            bootstrap = 200L, iseed = 20261030L, parallel = "no"))
fm <- fitMeasures(fit)
kv <- function(rows, label) { for (r in rows) if (identical(r[[1]], label)) return(r[[2]]); NA }
chk("DFA χ² (Wishart)", kv(ui$cfa_fit, "χ²"), f(fm[["chisq"]], 3, FALSE))
chk("DFA CFI", kv(ui$cfa_fit, "CFI"), f(fm[["cfi"]]))
chk("DFA TLI", kv(ui$cfa_fit, "TLI"), f(fm[["tli"]], 3, FALSE))
chk("DFA RMSEA %90 GA", kv(ui$cfa_fit, "RMSEA %90 GA"), sprintf("[%s; %s]", f(fm[["rmsea.ci.lower"]]), f(fm[["rmsea.ci.upper"]])))
chk("DFA SRMR", kv(ui$cfa_fit, "SRMR"), f(fm[["srmr"]]))
bs <- lavInspect(fit, "test")$bollen.stine
chk("Bollen–Stine B_etkin", kv(ui$cfa_bs, "Geçerli tekrar (B_etkin)"), as.character(bs$boot.length))
chk("Bollen–Stine b", kv(ui$cfa_bs, "Gözlenen χ²'den büyük bootstrap χ² sayısı (b)"), as.character(bs$boot.larger))
chk("Bollen–Stine p", kv(ui$cfa_bs, "p (lavaan: b / B_etkin)"),
    if (bs$boot.larger == 0) paste0("< ", f(ceiling(1000 / bs$boot.length) / 1000)) else f(bs$pvalue))
chk("Bollen–Stine tutucu p", kv(ui$cfa_bs, "Tutucu p: (b + 1) / (B_etkin + 1)"), f((bs$boot.larger + 1) / (bs$boot.length + 1)))
ss <- standardizedSolution(fit); ld <- ss[ss$op == "=~", ]
for (k in c(1, 2, 5, 9)) chk(sprintf("DFA β %s", ld$rhs[k]), ui$cfa_loadings[[k]][[7]], f(ld$est.std[k]))
chk("Yol şeması etiketi visual→x2", ui$path_label_visual_x2, f(ld$est.std[ld$lhs == "visual" & ld$rhs == "x2"], 2))
# Karşılaştırma (ML, Wishart)
fit3 <- cfa(m3, hs, likelihood = "wishart"); fit1 <- cfa("g =~ x1 + x2 + x3 + x4 + x5 + x6 + x7 + x8 + x9", hs, likelihood = "wishart")
a <- anova(fit3, fit1)
chk("Tek faktör χ²", ui$cmp_fit[[2]][[3]], f(fitMeasures(fit1, "chisq")[[1]], 3, FALSE))
chk("Δχ² (tek – üç faktör)", ui$cmp_tests[[1]][[3]], f(a[2, "Chisq diff"], 2, FALSE))
chk("Δsd", ui$cmp_tests[[1]][[4]], as.character(a[2, "Df diff"]))
chk("ΔCFI", ui$cmp_tests[[1]][[7]], f(fitMeasures(fit1, "cfi")[[1]] - fitMeasures(fit3, "cfi")[[1]]))
# Güvenirlik (ML, normal; obs.var = TRUE; HTMT Pearson, htmt2 = FALSE, absolute = TRUE)
fr <- cfa(m3, hs)
om <- compRelSEM(fr, obs.var = TRUE, ord.scale = TRUE, simplify = TRUE); av <- AVE(fr, obs.var = TRUE)
ht <- htmt(m3, hs, htmt2 = FALSE, absolute = TRUE)
chk("α visual", ui$rel_t1[[1]][[3]], f(alpha(hs[, 1:3], check.keys = FALSE, warnings = FALSE)$total$raw_alpha))
chk("ω visual", ui$rel_t1[[1]][[4]], f(om[["visual"]]))
chk("ω textual", ui$rel_t1[[2]][[4]], f(om[["textual"]]))
chk("AVE speed", ui$rel_t1[[3]][[5]], f(av[["speed"]]))
chk("α toplam", ui$rel_t1[[4]][[3]], f(alpha(hs, check.keys = FALSE, warnings = FALSE)$total$raw_alpha))
chk("HTMT textual–visual", ui$rel_htmt[[2]][[2]], f(ht["textual", "visual"]))
chk("HTMT speed–textual", ui$rel_htmt[[3]][[3]], f(ht["speed", "textual"]))
tab <- do.call(rbind, res)
print(tab, row.names = FALSE)
cat(sprintf("\n%d/%d AYNI\n", sum(tab$sonuc == "AYNI"), nrow(tab)))
cat("Ayrıca: açık temada yol şeması kenar rengi", ui$path_ellipse_stroke_light, "; yatay kaydırma (masaüstü/mobil):", ui$horizontal_scroll, ui$mobile_horizontal_scroll, "\n")
