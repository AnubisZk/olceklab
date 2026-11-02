# İstek gövdesindeki ayarları doğrulayan yardımcılar. Hatalar 422 ile döner.

setting_choice <- function(x, name, choices, default = choices[1]) {
  v <- x[[name]]
  if (is.null(v)) return(default)
  if (!is.character(v) || length(v) != 1L || !(v %in% choices)) {
    api_stop("invalid_setting",
             sprintf("'%s' ayarı şunlardan biri olmalıdır: %s.", name, paste(choices, collapse = ", ")), 422L)
  }
  v
}

setting_number <- function(x, name, default, min = -Inf, max = Inf, integer = FALSE) {
  v <- x[[name]]
  if (is.null(v)) return(default)
  if (!is.numeric(v) || length(v) != 1L || is.na(v) || v < min || v > max || (integer && v != round(v))) {
    api_stop("invalid_setting",
             sprintf("'%s' ayarı %s ile %s arasında %s olmalıdır.", name, format(min), format(max),
                     if (integer) "bir tam sayı" else "bir sayı"), 422L)
  }
  if (integer) as.integer(v) else as.numeric(v)
}

setting_flag <- function(x, name, default) {
  v <- x[[name]]
  if (is.null(v)) return(default)
  if (!is.logical(v) || length(v) != 1L || is.na(v)) {
    api_stop("invalid_setting", sprintf("'%s' ayarı true ya da false olmalıdır.", name), 422L)
  }
  v
}
