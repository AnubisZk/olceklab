# A UTF-8 locale is mandatory: Turkish messages and column names are UTF-8.
# Under a C/POSIX locale R may silently truncate UTF-8 source files at the first
# non-ASCII character, so functions would go missing. Fail early and loudly.
# This file is sourced first (by name) and is kept pure ASCII on purpose.
if (!isTRUE(l10n_info()[["UTF-8"]])) {
  stop("OlcekLab engine requires a UTF-8 locale (e.g. LANG=C.UTF-8). Current: ",
       Sys.getlocale("LC_CTYPE"), call. = FALSE)
}
