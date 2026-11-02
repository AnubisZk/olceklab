# Analizler mirai işçilerinde çalışır (SPEC §3 işçi modeli; SPEC_REVIEW ARCH-1).
# Ana süreç yalnızca yönlendirme ve oturum işlerini yapar; böylece uzun bir analiz
# sırasında /health yanıt vermeye devam eder. Veri işçiye bellek üzerinden gider.

engine_r_files <- function(engine_dir) {
  sort(list.files(file.path(engine_dir, "R"), pattern = "[.]R$", full.names = TRUE, recursive = TRUE))
}

workers_start <- function(n, engine_dir) {
  n <- as.integer(n)
  if (is.na(n) || n < 1L) {
    .olceklab$workers <- 0L
    return(invisible(0L))
  }
  mirai::daemons(n)
  files <- engine_r_files(engine_dir)
  mirai::everywhere({
    for (f in files) source(f, local = FALSE, encoding = "UTF-8")
  }, files = files)
  .olceklab$workers <- n
  invisible(n)
}

workers_stop <- function() {
  if (isTRUE(.olceklab$workers > 0L)) mirai::daemons(0)
  .olceklab$workers <- 0L
  invisible(TRUE)
}

# İşçide çalışan sarmalayıcı: hata nesneleri süreç sınırını güvenle geçsin diye
# sonuç, düz bir listeye çevrilir.
worker_call <- function(fun, args) {
  tryCatch(
    list(ok = TRUE, value = do.call(fun, args)),
    api_error = function(e) {
      list(ok = FALSE, status = e$status, body = api_error_body(e$code, conditionMessage(e), e$detail))
    },
    error = function(e) {
      list(ok = FALSE, status = 500L,
           body = api_error_body("engine_error", "R motorunda beklenmeyen bir hata oluştu.", conditionMessage(e)))
    }
  )
}

# fun: işçide tanımlı fonksiyonun adı. then: başarılı sonucu ana süreçte işler
# (ör. oturuma yazar) ve yanıt gövdesini döndürür.
run_in_worker <- function(res, fun, args, then = identity) {
  finish <- function(out) {
    if (!isTRUE(out$ok)) {
      res$status <- out$status
      return(out$body)
    }
    tryCatch(then(out$value), api_error = function(e) {
      res$status <- e$status
      api_error_body(e$code, conditionMessage(e), e$detail)
    })
  }
  if (!isTRUE(.olceklab$workers > 0L)) return(finish(worker_call(fun, args)))
  m <- mirai::mirai(worker_call(fun, args), fun = fun, args = args)
  promises::then(
    m,
    onFulfilled = function(out) {
      if (mirai::is_mirai_error(out) || mirai::is_error_value(out)) {
        res$status <- 500L
        return(api_error_body("worker_error", "Analiz işçisi hata verdi.", paste(as.character(out), collapse = " ")))
      }
      finish(out)
    },
    onRejected = function(e) {
      res$status <- 500L
      api_error_body("worker_error", "Analiz işçisi hata verdi.", conditionMessage(e))
    }
  )
}
