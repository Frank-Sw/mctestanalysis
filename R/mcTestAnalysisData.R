#' MC Test Analysis Data
#'
#' Load test and answer key data with \code{\link{loadTestData}} and
#' \code{\link{loadAnswerKey}}. Creates an MC Test Analysis data object.
#'
#' @section Answer Key Data Format:
#' The Answer Key file should contain four columns in the following order:
#' \enumerate{
#'    \item Question number, name or identifier: Eg. \code{"Q1"}, \code{"1"}, etc.
#'    \item The correct answer for the question: Eg. \code{"1"}, \code{"A"}, etc.
#'    \item A descriptive title for the question: Eg. \code{"Taylor Function"},
#'          \code{"Tensor Flow"}, etc.
#'    \item An identifier for the concept group to which the question belongs:
#'          Eg. \code{"Taylor Series"}, \code{"A"}, \code{"Concept 1"}, etc.
#' }
#'
#' @section Test Data Format:
#' The test results data should contain as rows each student's response, with
#' each question assigned a column. If the test results data contains student
#' identifiers, these identifiers should be included in the first column, prior
#' to the test answers. The MC Test Analysis Tool assumes that the question
#' columns are in the same order as reported in the answers data.
#'
#' @param mctd Existing mcTestAnalysis data object
#' @name mcTestAnalysisData
NULL

#' @describeIn mcTestAnalysisData Reads test data from CSV or TSV file and applies basic preprocessing.
#' @inheritParams mcTestAnalysisData
#' @param test_file Path to the test results data file
#' @param has_student_id Does the first column of the test data include a student identifier?
#' @param ... Arguments passed to \code{\link{read.csv}}
#' @export
loadTestData <- function(mctd = NULL, test_file, has_student_id = TRUE, ...) {
  if (is.null(mctd)) mctd <- list()
  x <- read.csv(test_file, stringsAsFactors = FALSE, ...)

  if (has_student_id) {
    x <- tibble::column_to_rownames(x, names(x)[1])
  }
  if ('AnswerKey' %in% names(mctd)) {
    check_questions_and_answers(x, mctd$AnswerKey)
    colnames(x) <- mctd$AnswerKey$Question
  }
  mctd[['Test']] <- x
  mctd[['Test.complete']] <- x[complete.cases(x), ]
  return(mctd)
}

#' @describeIn mcTestAnalysisData Reads answer_key data from CSV or TSV file and applies basic preprocessing.
#' @inheritParams mcTestAnalysisData
#' @param answer_file Path to the answer key data file
#' @export
loadAnswerKey <- function(mctd = NULL, answer_file, ...) {
  if (is.null(mctd)) mctd <- list()
  x <- read.csv(answer_file, stringsAsFactors = FALSE, ...)

  required_columns <- c('Question', 'Answer')
  optional_columns <- c('Title', 'Concept')

  # If more than 4 cols, truncate
  # If less than 4, assume ordered: required, optional, fill in missing

  if (ncol(x) > 4) {
    warning("Input data contained more than four columns, using only first four.")
    x <- x[, 1:4]
  } else if (ncol(x) == 3) {
    warning("Input data contained 3 columns, assumed to be Question, Answer, Title. Default value used for Concept.")
    x$Concept <- 'General'
  } else if (ncol(x) == 2) {
    warning("Input data contained 2 columns, assumed to be Question, Answer. Default values used for Title and Concept.")
    x$Title   <- paste('Question', x[, 1])
    x$Concept <- 'General'
  }

  colnames(x) <- c(required_columns, optional_columns)

  # Missing concepts given "Missing" concept group
  x[is.na(x$Concept), 'Concept'] <- "Missing"

  # Question column is character
  x$Question <- as.character(x$Question)

  mctd[['AnswerKey']] <- x
  return(mctd)
}


#' @describeIn mcTestAnalysisData Read answer_key and test data from CSV or TSV
#'   files
#' @param force_load Force calculation of test analysis items (may be slow).
#'   Default is \code{FALSE} as individual analysis will calculate needed
#'   analysis portions on the fly when called.
#' @export
loadAllData <- function(answer_file = NULL,
                        test_file = NULL, has_student_id = TRUE,
                        force_load = FALSE, ...) {
  mctd <- NULL
  if (!is.null(answer_file)) mctd <- loadAnswerKey(mctd, answer_file, ...)
  if (!is.null(test_file))   mctd <- loadTestData(mctd, test_file, has_student_id, ...)
  if (all(c('AnswerKey', 'Test.complete') %in% names(mctd)) && force_load) {
    mctd <- addItemAnalysis(mctd, disc = TRUE)
    mctd <- addAlpha(mctd)
    mctd <- addDiscriminationIndex(mctd)
    mctd <- addPBCC(mctd)
    mctd <- addPBCCmodified(mctd)
    mctd <- addIRTfits(mctd)
  }
  return(mctd)
}

check_questions_and_answers <- function(test, answer_key) {
  n.answers <- nrow(answer_key)
  n.questions <- ncol(test)
  if (n.answers != n.questions) {
    stop('Question-Answer mismatch: Answer key has ', n.answers, ' items, but Test contains ', n.questions, call. = FALSE)
  }
}


requires <- function(mctd, required, verbose = FALSE) {
  for (requirement in required) {
    if (!(requirement %in% names(mctd))) {
      if (verbose) warning('Adding ', requirement, ' to MCTD')
      mctd <- switch(
        requirement,
        'item.score'           = addItemScore(mctd),
        'item.analysis'        = addItemAnalysis(mctd, disc = TRUE),
        'alpha'                = addAlpha(mctd),
        'scores'               = addItemScore(mctd),
        'discrimination_index' = addDiscriminationIndex(mctd),
        'pbcc'                 = addPBCC(mctd),
        'pbcc_modified'        = addPBCCmodified(mctd),
        'irt_models'           = addIRTfits(mctd),
        'tetrachoric'          = addTetrachoric(mctd)
      )
    }
  }
  return(mctd)
}
