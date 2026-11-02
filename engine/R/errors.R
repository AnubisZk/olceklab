# Hata biçimi (SPEC §8):
#   { "error": { "code": "...", "message_tr": "...", "detail": "R hata metni" } }

api_error_body <- function(code, message_tr, detail = NULL) {
  stopifnot(is.character(code), length(code) == 1L, nzchar(code))
  stopifnot(is.character(message_tr), length(message_tr) == 1L, nzchar(message_tr))
  list(error = list(code = code, message_tr = message_tr, detail = detail))
}

# Henüz uygulanmamış uç noktalar sahte sonuç yerine 501 döndürür (AGENTS kuralı 2).
not_implemented_handler <- function(module, phase) {
  force(module); force(phase)
  function(req, res) {
    res$status <- 501L
    api_error_body(
      code = "not_implemented",
      message_tr = sprintf("Bu analiz henüz uygulanmadı (%s, Faz %s).", module, phase),
      detail = sprintf("%s %s", req$REQUEST_METHOD, req$PATH_INFO)
    )
  }
}

#' Kullanıcıya gösterilecek, durum kodlu hata. İşçiden ana sürece güvenle taşınır.
api_stop <- function(code, message_tr, status = 400L, detail = NULL) {
  cond <- structure(
    class = c("api_error", "error", "condition"),
    list(message = message_tr, call = NULL, code = code, status = as.integer(status), detail = detail)
  )
  stop(cond)
}

engine_error_handler <- function(req, res, err) {
  if (inherits(err, "api_error")) {
    res$status <- err$status
    return(api_error_body(err$code, conditionMessage(err), err$detail))
  }
  res$status <- 500L
  api_error_body(
    code = "engine_error",
    message_tr = "R motorunda beklenmeyen bir hata oluştu.",
    detail = conditionMessage(err)
  )
}

engine_404_handler <- function(req, res) {
  res$status <- 404L
  api_error_body(
    code = "not_found",
    message_tr = "İstenen uç nokta bulunamadı.",
    detail = sprintf("%s %s", req$REQUEST_METHOD, req$PATH_INFO)
  )
}
