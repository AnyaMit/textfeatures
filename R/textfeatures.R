
#' textfeatures
#'
#' Extracts features from text vector.
#'
#' @param text Input data. Should be character vector or data frame with character
#'   variable of interest named "text". If a data frame then the first "id|*_id"
#'   variable, if found, is assumed to be an ID variable.
#' @param sentiment Logical, indicating whether to return sentiment analysis
#'   features, the variables \code{sent_afinn} and \code{sent_bing}. Defaults to
#'   FALSE. Setting this to true will speed things up a bit.
#' @param word_dims Integer indicating the desired number of word2vec dimension
#'   estimates. When NULL, the default, this function will pick a reasonable
#'   number of dimensions (ranging from 2 to 200) based on size of input. To
#'   disable word2vec estimates, set this to 0 or FALSE.
#' @param normalize Logical indicating whether to normalize (mean center,
#'   sd = 1) features. Defaults to TRUE.
#' @return A tibble data frame with extracted features as columns.
#' @examples
#'
#' ## the text of five of Trump's most retweeted tweets
#' trump_tweets <- c(
#'   "#FraudNewsCNN #FNN https://t.co/WYUnHjjUjg",
#'   "TODAY WE MAKE AMERICA GREAT AGAIN!",
#'   paste("Why would Kim Jong-un insult me by calling me \"old,\" when I would",
#'     "NEVER call him \"short and fat?\" Oh well, I try so hard to be his",
#'     "friend - and maybe someday that will happen!"),
#'   paste("Such a beautiful and important evening! The forgotten man and woman",
#'     "will never be forgotten again. We will all come together as never before"),
#'   paste("North Korean Leader Kim Jong Un just stated that the \"Nuclear",
#'     "Button is on his desk at all times.\" Will someone from his depleted and",
#'     "food starved regime please inform him that I too have a Nuclear Button,",
#'     "but it is a much bigger &amp; more powerful one than his, and my Button",
#'     "works!")
#' )
#'
#' ## get the text features of a character vector
#' textfeatures(trump_tweets)
#'
#' ## data frame with a character vector named "text"
#' df <- data.frame(
#'   id = c(1, 2, 3),
#'   text = c("this is A!\t sEntence https://github.com about #rstats @github",
#'     "and another sentence here",
#'     "The following list:\n- one\n- two\n- three\nOkay!?!"),
#'   stringsAsFactors = FALSE
#' )
#'
#' ## get text features of a data frame with "text" variable
#' textfeatures(df)
#'
#' @export
textfeatures <- function(text,
                         sentiment = TRUE,
                         word_dims = NULL,
                         normalize = TRUE,
                         newdata = NULL) {
  UseMethod("textfeatures")
}

#' @export
textfeatures.character <- function(text,
                                   sentiment = TRUE,
                                   word_dims = NULL,
                                   normalize = TRUE,
                                   newdata = NULL) {

  ## validate inputs
  stopifnot(
    is.character(text),
    is.logical(sentiment),
    is.atomic(word_dims),
    is.logical(normalize)
  )

  ## initialize output data
  o <- tweet_features(text)

  ## length
  n_obs <- length(text)

  ## tokenize into words
  text <- prep_wordtokens(text)

  ## estimate sentiment
  if (sentiment) {
    tfse::print_start("Sentiment analysis...")
    o$sent_afinn <- sentiment_afinn(text)
    o$sent_bing <- sentiment_bing(text)
    o$sent_syuzhet <- sentiment_syuzhet(text)
    o$sent_vader <- sentiment_vader(text)
    o$n_polite <- politeness(text)
  }

  ## parts of speech
  tfse::print_start("Parts of speech...")
  o$n_first_person <- first_person(text)
  o$n_first_personp <- first_personp(text)
  o$n_second_person <- second_person(text)
  o$n_second_personp <- second_personp(text)
  o$n_third_person <- third_person(text)
  o$n_tobe <- to_be(text)
  o$n_prepositions <- prepositions(text)

  ## get word dim estimates
  w <- estimate_word_dims(text, word_dims, n_obs)

  ## convert 'o' into to tibble and merge with w
  o <- tibble::as_tibble(o)
  o <- dplyr::bind_cols(o, w)

  ## make exportable
  m <- vapply(o, mean, na.rm = TRUE, FUN.VALUE = numeric(1))
  s <- vapply(o, stats::sd, na.rm = TRUE, FUN.VALUE = numeric(1))
  e <- list(avg = m, std_dev = s)
  e$dict <- attr(w, "dict")

  ## normalize
  if (normalize) {
    tfse::print_start("Normalizing data")
    o <- scale_normal(scale_count(o))
  }

  ## store export list as attribute
  attr(o, "tf_export") <- structure(e,
    class = c("textfeatures_model", "list")
  )

  ## done!
  tfse::print_complete("Job's done!")

  ## return
  o
}

#' @export
textfeatures.factor <- function(text,
                                sentiment = TRUE,
                                word_dims = NULL,
                                normalize = TRUE,
                                newdata = newdata) {
  textfeatures(
    as.character(text),
    sentiment = sentiment,
    word_dims = word_dims,
    normalize = normalize,
    newdata = newdata
  )
}

#' @export
textfeatures.data.frame <- function(text,
                                    sentiment = TRUE,
                                    word_dims = NULL,
                                    normalize = TRUE,
                                    newdata = newdata) {

  ## validate input
  stopifnot("text" %in% names(text))
  textfeatures(
    text$text,
    sentiment = sentiment,
    word_dims = word_dims,
    normalize = normalize,
    newdata = newdata
  )
}
