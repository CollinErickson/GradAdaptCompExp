% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/adaptconcept2_sFFLHD_R6_desfuncs.R
\name{des_func_quantile}
\alias{des_func_quantile}
\title{Test desirability functions}
\usage{
des_func_quantile(
  mod,
  XX,
  threshold = 0,
  power = 1,
  return_se = F,
  N_add = 1000,
  threshold_jump = 0
)
}
\arguments{
\item{mod}{GP model}

\item{XX}{Points to evaluate at}

\item{threshold}{Scalar in [0,1) thresholding how big the quantile should be.}

\item{power}{The power the quantiles will be raised to after thresholding.}

\item{return_se}{whether the se prediction should be returned along with
the des, all will be returned in data.frame, this will save
time if calculating the werror function since it is faster
to predict both at once instead of separately}

\item{N_add}{Number of points to add}

\item{threshold_jump}{Parameter, leave as 0}
}
\description{
A des func where output is scaled 0 to 1, max higher
}
