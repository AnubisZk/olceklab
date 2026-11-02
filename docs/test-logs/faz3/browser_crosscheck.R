# Faz 3: tarayıcıda görünen değişmezlik metinleri ↔ bağımsız R hesabı (lavaan doğrudan; biçimleme sprintf ile).
suppressPackageStartupMessages({library(lavaan); library(jsonlite)})
ui <- fromJSON(commandArgs(TRUE)[1], simplifyVector = FALSE)
f <- function(x, d = 3, bounded = TRUE) {
  s <- sprintf(paste0("%.", d, "f"), abs(x)); if (bounded) s <- sub("^0\\.", ".", s); s <- sub(".", ",", s, fixed = TRUE)
  if (x < 0 && grepl("[1-9]", s)) s <- paste0("−", s); s
}
res <- list(); chk <- function(w, a, b) res[[length(res) + 1L]] <<- data.frame(olcut = w, arayuz = a, bagimsiz_R = b, sonuc = if (identical(a, b)) "AYNI" else "FARKLI")
hs <- HolzingerSwineford1939; hs$school <- as.character(hs$school)
m <- "visual =~ x1 + x2 + x3\ntextual =~ x4 + x5 + x6\nspeed =~ x7 + x8 + x9"
fit <- function(eq = NULL, p = NULL) { a <- list(m, data = hs, group = "school", group.label = c("Pasteur", "Grant-White"), likelihood = "wishart", std.lv = TRUE)
  if (length(eq)) a$group.equal <- eq; if (length(p)) a$group.partial <- p; do.call(cfa, a) }
for (case in list(list(tag = "full", p = NULL), list(tag = "partial", p = ui$released))) {
  cf <- fit(); me <- fit("loadings", case$p); sc <- fit(c("loadings", "intercepts"), case$p)
  fitrows <- ui[[paste0(case$tag, "_fit")]]; cmprows <- ui[[paste0(case$tag, "_cmp")]]
  for (k in 1:3) {
    fm <- fitMeasures(list(cf, me, sc)[[k]])
    chk(sprintf("%s adım %d χ²", case$tag, k), fitrows[[k]][[2]], f(fm[["chisq"]], 3, FALSE))
    chk(sprintf("%s adım %d CFI", case$tag, k), fitrows[[k]][[5]], f(fm[["cfi"]]))
    chk(sprintf("%s adım %d SRMR (Bentler)", case$tag, k), fitrows[[k]][[10]], f(fm[["srmr_bentler_nomean"]], 4))
  }
  a <- anova(cf, me); b <- anova(me, sc)
  chk(paste(case$tag, "metrik Δχ²"), cmprows[[1]][[3]], f(a[2, "Chisq diff"], 2, FALSE))
  chk(paste(case$tag, "skaler Δχ²"), cmprows[[2]][[3]], f(b[2, "Chisq diff"], 2, FALSE))
  chk(paste(case$tag, "skaler ΔCFI"), cmprows[[2]][[7]], f(fitMeasures(sc, "cfi")[[1]] - fitMeasures(me, "cfi")[[1]]))
  pe <- parameterEstimates(sc); n <- lavInspect(sc, "nobs")
  for (j in 1:3) {
    fac <- c("visual", "textual", "speed")[j]
    k <- pe$est[pe$op == "~1" & pe$lhs == fac & pe$group == 2]; v2 <- pe$est[pe$op == "~~" & pe$lhs == fac & pe$rhs == fac & pe$group == 2]
    chk(sprintf("%s κ %s", case$tag, fac), ui[[paste0(case$tag, "_latent")]][[j]][[3]], f(k, 3, FALSE))
    chk(sprintf("%s d %s", case$tag, fac), ui[[paste0(case$tag, "_latent")]][[j]][[7]], f(k / sqrt(((n[1] - 1) + (n[2] - 1) * v2) / (n[1] + n[2] - 2)), 3, FALSE))
  }
}
sc_full <- fit(c("loadings", "intercepts"))
st <- lavTestScore(sc_full, univariate = TRUE, cumulative = FALSE)$uni
top <- st[which.max(st$X2), ]; pt <- parTable(sc_full); r <- pt[pt$plabel == top$lhs, ]
chk("en büyük skor testi parametresi", ui$released, if (r$op == "~1") paste0(r$lhs, "~1") else paste0(r$lhs, r$op, r$rhs))
chk("en büyük skor testi χ²", ui$scores_top[[1]][[4]], f(top$X2, 3, FALSE))
tab <- do.call(rbind, res); print(tab, row.names = FALSE)
cat(sprintf("\n%d/%d AYNI; mobil yatay kaydırma: %s\n", sum(tab$sonuc == "AYNI"), nrow(tab), ui$mobile_horizontal_scroll))
