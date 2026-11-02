# JSON serileştirme — sayılar tam duyarlıkla gönderilir.
#
# jsonlite::toJSON varsayılan olarak 4 ondalık basamak yazar (digits = 4);
# digits = NA bile yalnızca 15 anlamlı basamak verir ve pi gibi değerler JSON'dan
# geri okunduğunda birebir aynı çıkmaz. IEEE 754 çift duyarlıklı sayının kayıpsız
# gidiş-dönüşü için 17 anlamlı basamak gerekir: digits = I(17).
# Ekranda gösterilecek biçimli metin ayrıca R tarafından üretilir (SPEC_REVIEW REP-3).

engine_json_options <- list(
  auto_unbox = TRUE,
  digits = I(17),
  null = "null",
  na = "null"
)

to_json <- function(x) {
  do.call(jsonlite::toJSON, c(list(x), engine_json_options))
}

serializer_engine_json <- function() {
  do.call(plumber::serializer_unboxed_json, engine_json_options[c("digits", "null", "na")])
}
