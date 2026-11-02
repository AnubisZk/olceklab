# Sayı biçimleme — yalnızca R'de yapılır (SPEC §0 kural 10, M10; SPEC_REVIEW REP-3).
# APA 7: değeri 1'i geçemeyen istatistiklerde baştaki sıfır yazılmaz (bounded = TRUE).
# Türkçe: ondalık virgülü, binlik nokta; İngilizce: ondalık nokta, binlik virgül.
# Eksi işareti U+2212'dir; sıfıra yuvarlanan negatif değer işaretsiz yazılır.

FMT_MISSING <- "—"
FMT_MINUS <- "−"

fmt_marks <- function(lang) {
  lang <- match.arg(lang, c("tr", "en"))
  if (lang == "tr") list(dec = ",", big = ".") else list(dec = ".", big = ",")
}

fmt_num <- function(x, digits = 2L, lang = "tr", bounded = FALSE) {
  m <- fmt_marks(lang)
  x <- suppressWarnings(as.numeric(x))
  out <- rep(FMT_MISSING, length(x))
  ok <- !is.na(x) & is.finite(x)
  if (any(ok)) {
    s <- formatC(abs(x[ok]), format = "f", digits = as.integer(digits),
                 big.mark = m$big, decimal.mark = m$dec)
    if (bounded) s <- sub(paste0("^0\\", m$dec), m$dec, s)
    is_zero <- !grepl("[1-9]", s)
    neg <- x[ok] < 0 & !is_zero
    out[ok] <- paste0(ifelse(neg, FMT_MINUS, ""), s)
  }
  out
}

fmt_int <- function(x, lang = "tr") {
  m <- fmt_marks(lang)
  x <- suppressWarnings(as.numeric(x))
  out <- rep(FMT_MISSING, length(x))
  ok <- !is.na(x) & is.finite(x)
  if (any(ok)) {
    s <- formatC(abs(round(x[ok])), format = "d", big.mark = m$big, decimal.mark = m$dec)
    out[ok] <- paste0(ifelse(x[ok] < 0, FMT_MINUS, ""), s)
  }
  out
}

fmt_p <- function(p, lang = "tr", digits = 3L) {
  m <- fmt_marks(lang)
  p <- suppressWarnings(as.numeric(p))
  out <- fmt_num(p, digits, lang, bounded = TRUE)
  small <- !is.na(p) & p < 10^(-digits)
  out[small] <- paste0("< ", m$dec, strrep("0", digits - 1L), "1")
  out
}

fmt_pct <- function(prop, lang = "tr", digits = 1L) {
  lang <- match.arg(lang, c("tr", "en"))
  num <- fmt_num(100 * suppressWarnings(as.numeric(prop)), digits, lang)
  ifelse(num == FMT_MISSING, num, if (lang == "tr") paste0("%", num) else paste0(num, "%"))
}

# --- Tablolar (SPEC §6.2) ---------------------------------------------------

tbl_col <- function(key, label_tr, label_en = label_tr,
                    format = c("text", "num", "int", "p", "pct"),
                    digits = 2L, bounded = FALSE) {
  format <- match.arg(format)
  list(key = key, label_tr = label_tr, label_en = label_en, format = format,
       digits = as.integer(digits), bounded = isTRUE(bounded),
       type = if (format == "text") "text" else "number")
}

fmt_column <- function(values, col, lang) {
  switch(col$format,
    text = ifelse(is.na(values), FMT_MISSING, as.character(values)),
    num  = fmt_num(values, col$digits, lang, col$bounded),
    int  = fmt_int(values, lang),
    p    = fmt_p(values, lang, max(3L, col$digits)),
    pct  = fmt_pct(values, lang, col$digits)
  )
}

make_table <- function(id, title_tr, title_en, columns, rows, note_tr = NULL, note_en = NULL) {
  stopifnot(is.data.frame(rows))
  keys <- vapply(columns, `[[`, "", "key")
  missing_keys <- setdiff(keys, names(rows))
  if (length(missing_keys)) stop("Tabloda olmayan sütun: ", paste(missing_keys, collapse = ", "))
  rows <- rows[, keys, drop = FALSE]
  rownames(rows) <- NULL
  fmt_rows <- function(lang) {
    out <- as.data.frame(lapply(seq_along(columns), function(j) fmt_column(rows[[j]], columns[[j]], lang)),
                         stringsAsFactors = FALSE, check.names = FALSE)
    names(out) <- keys
    out
  }
  list(
    id = id, title_tr = title_tr, title_en = title_en,
    columns = lapply(columns, function(c) c[c("key", "label_tr", "label_en", "type")]),
    rows = rows,
    rows_fmt = list(tr = fmt_rows("tr"), en = fmt_rows("en")),
    note_tr = note_tr, note_en = note_en
  )
}

# Güven aralığı: TR "[,045; ,067]" (ondalık virgülüyle karışmasın diye noktalı virgül), EN "[.045, .067]".
fmt_ci <- function(lo, hi, digits = 3L, lang = "tr", bounded = FALSE) {
  a <- fmt_num(lo, digits, lang, bounded); b <- fmt_num(hi, digits, lang, bounded)
  ifelse(a == FMT_MISSING & b == FMT_MISSING, FMT_MISSING,
         paste0("[", a, if (lang == "tr") "; " else ", ", b, "]"))
}

fmt_value <- function(v, format, digits = 2L, bounded = FALSE, lang = "tr") {
  switch(format,
    text = ifelse(is.na(v), FMT_MISSING, as.character(v)),
    num  = fmt_num(v, digits, lang, bounded),
    int  = fmt_int(v, lang),
    p    = fmt_p(v, lang, max(3L, digits)),
    pct  = fmt_pct(v, lang, digits),
    stop("Bilinmeyen biçim: ", format))
}

# Satır başına biçimli "ölçüt–değer" tablosu (ör. uyum indeksleri: χ² iki basamak, CFI baştaki sıfırsız).
# rows: key, label_tr, label_en, format, digits, bounded ve her değer sütunu için bir sayısal sütun.
# text_values[[satır]][[sütun]] = list(tr = , en = ) ile metin değerli hücreler (ör. güven aralığı) verilir.
make_kv_table <- function(id, title_tr, title_en, rows,
                          value_cols = list(tbl_col("value", "Değer", "Value", "num")),
                          text_values = list(), note_tr = NULL, note_en = NULL) {
  stopifnot(is.data.frame(rows), all(c("key", "label_tr", "label_en", "format", "digits", "bounded") %in% names(rows)))
  vkeys <- vapply(value_cols, `[[`, "", "key")
  missing_keys <- setdiff(vkeys, names(rows))
  if (length(missing_keys)) stop("Tabloda olmayan sütun: ", paste(missing_keys, collapse = ", "))
  raw <- data.frame(key = rows$key, label = rows$label_tr, stringsAsFactors = FALSE)
  for (vk in vkeys) raw[[vk]] <- rows[[vk]]
  fmt_rows <- function(lang) {
    out <- data.frame(key = rows$key, label = if (lang == "tr") rows$label_tr else rows$label_en, stringsAsFactors = FALSE)
    for (vk in vkeys) {
      out[[vk]] <- vapply(seq_len(nrow(rows)), function(i) {
        tv <- text_values[[rows$key[i]]][[vk]]
        if (!is.null(tv)) return(tv[[lang]])
        if (rows$format[i] == "text") return(FMT_MISSING)
        fmt_value(rows[[vk]][i], rows$format[i], rows$digits[i], rows$bounded[i], lang)
      }, "")
    }
    out
  }
  cols <- c(list(list(key = "label", label_tr = "Ölçüt", label_en = "Index", type = "text")),
            lapply(value_cols, function(c) c[c("key", "label_tr", "label_en", "type")]))
  list(id = id, title_tr = title_tr, title_en = title_en, columns = cols, rows = raw,
       rows_fmt = list(tr = fmt_rows("tr"), en = fmt_rows("en")), note_tr = note_tr, note_en = note_en)
}
