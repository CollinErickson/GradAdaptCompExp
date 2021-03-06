
<!-- README.md is generated from README.Rmd. Please edit that file -->

# GradAdaptCompExp

<!-- badges: start -->
<!-- badges: end -->

The goal of GradAdaptCompExp is to provide code for managing computer
experiments.

This code was from my (Collin Erickson) PhD work for the paper
[Gradient-based criteria for sequential experiment
design](https://onlinelibrary.wiley.com/doi/10.1002/qre.2981).

## Installation

You can install the development version of GradAdaptCompExp from
[GitHub](https://github.com/) with:

``` r
# install.packages("devtools")
devtools::install_github("CollinErickson/GradAdaptCompExp")
```

## Example

Here’s an example of how to use the code.

First, load the R package.

``` r
library(GradAdaptCompExp)
#> Registered S3 method overwritten by 'DoE.base':
#>   method           from       
#>   factorize.factor conf.design
## basic example code
```

Second, use `adapt.concept2.sFFLHD.R6$new` to create a new experiment.
`adapt.concept2.sFFLHD.R6` is an R6 class with many associated methods,
so we are just initializing a new instance of this class.

``` r
# wing weight, grad_norm2_mean, laGP_GauPro_kernel
a <- adapt.concept2.sFFLHD.R6$new(
  D=10,L=5,func=TestFunctions::wingweight, 
  nugget=1e-7, estimate.nugget = TRUE,
  obj="desirability", des_func=des_func_grad_norm2_mean,
  actual_des_func=NULL,
  stage1batches=6,
  design='sFFLHD_Lflex',
  error_power=2,
  selection_method="max_des_red_all_best"
); 
#> no suitable  resolution IV or more  array found
#> no suitable  orthogonal  array found
#> sFFLHD_Lflex requested L=5, but using L=11
```

Here’s what all the parameters we just gave in mean:

1.  `D=10`: There are 10 input dimensions for the function.

2.  `L=5`: We will evaluate in batches of size 5.

3.  `func=TestFunctions::wingweight`: This is the function we are
    evaluating. In this case it is the Wing Weight function, which has
    10 input dimensions (we already told it `D=10`), from the
    `TestFunctions` package.

4.  `nugget = 1e-7`: When fitting the Gaussian process model to the
    data, we will start with a nugget of 1e-7.

5.  `estimate.nugget = TRUE`: The nugget for the GP model will be
    estimated. This is recommended unless you know there is no noise in
    the function, and even then should probably be `TRUE`.

6.  `obj="desirability"`: This tells it how to pick points.
    `desirability` means it will pick points according to a criterion.

7.  `des_func=des_func_grad_norm2_mean`: This tells it which
    desirability function to use. In this case it is
    `des_func_grad_norm2_mean`, which is the gradient of the norm
    squared of the mean.

8.  `actual_des_func=NULL`: This is where we would give it true
    desirability function so that it can compare its predictions to the
    true values. In general this won’t be known and can be left as NULL
    or ignored completely.

9.  `stage1batches=6`: This is the number of stage 1 batches to use. In
    stage 1 the points are just chosen using the space filling design,
    not according to the desirability criterion. In this case, the total
    number of points chosen this way will be `6*5=30`, the 5 coming from
    `L` above.

10. `design='sFFLHD_Lflex'`: This tells it how to generate candidate
    points. This will use points from an sFFLHD, but will be flexible on
    the batch size. If you don’t let it be flexible, it may not be able
    to find a suitable sFFLHD for the given batch size.

11. `error_power=2`: Either 1 or 2. Whether you want to reduce the
    absolute error (1) or squared error (2).

12. `selection_method="max_des_red_all_best"`: This tells it that the
    points should be chosen to give the maximum reduction is
    desirability.

Here we actually start running the experiment using the `run` method. We
tell it to run 6 batches, which matches the number of space filling
batches.

``` r
a$run(6, noplot = TRUE)
#> Starting iteration 1 at 2021-11-25 21:56:00 
#> no suitable  resolution IV or more  array found
#> Warning in DoE.base::oa.design(nruns = L^2, nfactors = D + 1, nlevels = L, :
#> resources were not sufficient for optimizing column selection
#> Starting iteration 2 at 2021-11-25 21:56:02 
#> stage1batch adding
#> Starting iteration 3 at 2021-11-25 21:56:04 
#> stage1batch adding
#> Starting iteration 4 at 2021-11-25 21:56:07 
#> stage1batch adding
#> Starting iteration 5 at 2021-11-25 21:56:10 
#> stage1batch adding
#> Starting iteration 6 at 2021-11-25 21:56:16 
#> stage1batch adding
```

Now we tell it to plot its progress.

The top left plot shows how the predicted integrated weighted error
(PIWE) is decreasing. Since we didn’t give it the actual desirability
(weight) function, it can’t plot the IWE.

The top right plot is showing how accurate the model predictions are.
The x-axis is the true values, and the y-axis is the prediction
residual. The red points (Z) are for the data we have collected. They
have perfect predictions since they are included in the model. The black
points (ZZ) are when predicting at new points. The green bars are the
95% prediction intervals. Note that we haven’t evaluated these points
yet in the experiment, but it is evaluating these points for the plot.
In reality we wouldn’t do this since we wouldn’t have those points.

The bottom left plot shows the percentage of candidate points that we
have evaluted. Since we have been in stage 1 (space filling), it’s just
using all the points in order, so no points have been ignored.

The bottom right plot shows the desirability on the x-axis for a sample
of points. The black marks the predicted standard error from the GP
model. The red marks the actual absolute error for these points, which
is only done since we know the function be evaluated quickly.

``` r
a$plot1()
```

<img src="man/figures/README-e1 plot 1-1.png" width="100%" />

If we continue running the experiment, it will start to choose points
using the desirability function.

``` r
a$run(6, noplot = TRUE)
#> Starting iteration 7 at 2021-11-25 21:56:22 
#> Starting iteration 8 at 2021-11-25 21:56:34 
#> Starting iteration 9 at 2021-11-25 21:56:48 
#> Starting iteration 10 at 2021-11-25 21:57:05 
#> Starting iteration 11 at 2021-11-25 21:57:24 
#> Starting iteration 12 at 2021-11-25 21:57:45
```

Here are the updated plots. The top left plot is showing that the PIWE
is decreasing at a steady rate as more data is collected. The bottom
left plot is showing that we are using a smaller percentage of all
available points. This is good, it means it is being adaptive and not
just using the points from the space filling design.

``` r
a$plot1()
```

<img src="man/figures/README-e1 plot 2-1.png" width="100%" />
