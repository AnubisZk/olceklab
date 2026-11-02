# V07 — ARES-1 renklerinin WCAG 2.x kontrast oranları (eşik: normal metin 4.5:1)
lum <- function(hex) {
  rgb <- col2rgb(hex)[, 1] / 255
  lin <- ifelse(rgb <= 0.04045, rgb / 12.92, ((rgb + 0.055) / 1.055)^2.4)
  sum(c(0.2126, 0.7152, 0.0722) * lin)
}
ratio <- function(a, b) { l <- sort(c(lum(a), lum(b)), decreasing = TRUE); (l[1] + 0.05) / (l[2] + 0.05) }
pairs <- rbind(
  c("Koyu tema", "#00E5FF camgöbeği", "#070B10", "#00E5FF"),
  c("Koyu tema", "#FFB300 kehribar", "#070B10", "#FFB300"),
  c("Açık tema (şartnamedeki vurgular aynen)", "#00E5FF camgöbeği", "#FFFFFF", "#00E5FF"),
  c("Açık tema (şartnamedeki vurgular aynen)", "#FFB300 kehribar", "#FFFFFF", "#FFB300"),
  c("Açık tema (önerilen koyulaştırılmış vurgu)", "#00707F camgöbeği", "#FFFFFF", "#00707F"),
  c("Açık tema (önerilen koyulaştırılmış vurgu)", "#8A5A00 kehribar", "#FFFFFF", "#8A5A00"),
  c("Açık tema (önerilen yüzey)", "#00707F camgöbeği", "#F4F7FA", "#00707F"),
  c("Açık tema (önerilen yüzey)", "#8A5A00 kehribar", "#F4F7FA", "#8A5A00")
)
for (i in seq_len(nrow(pairs))) {
  r <- ratio(pairs[i, 3], pairs[i, 4])
  cat(sprintf("%-44s %-20s zemin %s : %5.2f:1  %s\n", pairs[i, 1], pairs[i, 2], pairs[i, 3], r, if (r >= 4.5) "GEÇER" else "KALIR"))
}
