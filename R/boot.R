#' Bootstrap Sampling
#'
#' A bootstrap sample is a sample that is the same size as the original data set that is made using replacement.  This results in analysis samples that have multiple replicates of some of the original rows of the data. The assessment set is defined as the rows of the original data that were not included in the bootstrap sample. This is often referred to as the "out-of-bag" (OOB) sample.

#' @details
#' The argument `apparent` enables the option of an additional "resample" where the analysis and assessment data sets are the same as the original data set. This can be required for some types of analysis of the bootstrap results.
#'
#' The `strata` argument is based on a similar argument in the random forest package were the bootstrap samples are conducted *within the stratification variable*. The can help ensure that the number of data points in the bootstrap sample is equivalent to the proportions in the original data set.
#'
#' @inheritParams vfold_cv
#' @param times The number of bootstrap samples.
#' @param strata A variable that is used to conduct stratified sampling. When not `NULL`, each bootstrap sample is created within the stratification variable.
#' @param apparent A logical. Should an extra resample be added where the analysis and holdout subset are the entire data set. This is required for some estimators used by the `summary` function that require the apparent error rate.
#' @export
#' @return  An tibble with classes `bootstraps`, `rset`, `tbl_df`, `tbl`, and `data.frame`. The results include a column for the data split objects and a column called `id` that has a character string with the resample identifier.
#' @examples
#' bootstraps(mtcars, times = 2)
#' bootstraps(mtcars, times = 2, apparent = TRUE)
#'
#' library(purrr)
#' iris2 <- iris[1:130, ]
#'
#' set.seed(13)
#' resample1 <- bootstraps(iris2, times = 3)
#' map_dbl(resample1$splits,
#'         function(x) {
#'           dat <- as.data.frame(x)$Species
#'           mean(dat == "virginica")
#'         })
#'
#' set.seed(13)
#' resample2 <- bootstraps(iris2, strata = "Species", times = 3)
#' map_dbl(resample2$splits,
#'         function(x) {
#'           dat <- as.data.frame(x)$Species
#'           mean(dat == "virginica")
#'         })
#' @export
bootstraps <-
  function(data,
           times = 25,
           strata = NULL,
           apparent = FALSE,
           ...) {

  strata_check(strata, names(data))

  split_objs <-
    boot_splits(
      data = data,
      times = times,
      strata = strata
    )
  if(apparent)
    split_objs <- bind_rows(split_objs, apparent(data))

  boot_att <- list(times = times,
                   apparent = apparent,
                   strata = !is.null(strata))

  new_rset(splits = split_objs$splits,
           ids = split_objs$id,
           attrib = boot_att,
           subclass = c("bootstraps", "rset"))

}

# Get the indices of the analysis set from the analysis set (= bootstrap sample)
boot_complement <- function(ind, n) {
  list(analysis = ind, assessment = NA)
}

#' @importFrom purrr map map_df
#' @importFrom tibble tibble
boot_splits <-
  function(data,
           times = 25,
           strata = NULL) {

  n <- nrow(data)

  if (is.null(strata)) {
    indices <- purrr::map(rep(n, times), sample, replace = TRUE)
  } else {
    stratas <- tibble::tibble(idx = 1:n,
                              strata = make_strata(getElement(data, strata)))
    stratas <- split(stratas, stratas$strata)
    stratas <-
      purrr::map_df(
        stratas,
        strat_sample,
        prop = 1,
        times = times,
        replace = TRUE
      )
    indices <- split(stratas$idx, stratas$rs_id)
  }

  indices <- lapply(indices, boot_complement, n = n)

  split_objs <-
    purrr::map(indices, make_splits, data = data, class = "boot_split")
  list(splits = split_objs,
       id = names0(length(split_objs), "Bootstrap"))
}

#' @export
print.bootstraps <- function(x, ...) {
  cat("#", pretty(x), "\n")
  class(x) <- class(x)[!(class(x) %in% c("bootstraps", "rset"))]
  print(x)
}
