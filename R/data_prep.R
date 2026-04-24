# function to clean up the issn
clean_issn <- function(x) {
  y <- str_to_upper(x)
  y <- str_replace_all(y, "[^0-9X]", "") # keep only digits/X

  # Must be 8 chars now to be considered an ISSN
  y[nchar(y) != 8] <- NA_character_

  # Insert hyphen
  y <- ifelse(is.na(y), NA_character_, paste0(substr(y, 1, 4), "-", substr(y, 5, 8)))

  y
}