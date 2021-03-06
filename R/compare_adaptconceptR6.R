# source("adaptconcept2_sFFLHD_R6.R")
# library(ggplot2)

#' @importFrom grDevices axisTicks
base_breaks <- function(n = 10){
  function(x) {
    axisTicks(log10(range(x, na.rm = TRUE)), log = TRUE, nint = n)
  }
}

#' Compare adapt R6
#' @export
compare.adaptR6 <- R6::R6Class("compare.adaptR6",
  public=list(
    func = NULL,
    D = NULL,
    L = NULL,
    b = NULL,
    batches = NULL,
    reps = NULL,
    obj = NULL,#=c("nonadapt", "grad"),
    #plot_after = NULL,#=c(),
    #plot_every = NULL,#=c(),
    forces = NULL,#=c("old"),
    force_vals = NULL,#=c(0),
    force_old = NULL,
    force_pvar = NULL,
    n0 = NULL,#=0,
    stage1batches = NULL,#=0
    save_output = NULL,#=F,
    func_string = NULL,
    seed_start = NULL, # Start with seed to make comparisons much better,
                       #  default is to use Sys.time() to get seed.
    design_seed_start = NULL,
    # folder_created = FALSE,
    folder_path = NULL,
    folder_name = NULL,
    outdf = data.frame(),
    outrawdf = data.frame(),
    plotdf = data.frame(),
    enddf = data.frame(),
    meandf = data.frame(),
    meanlogdf = data.frame(),
    endmeandf = data.frame(),
    rungrid = data.frame(),
    rungridlist = list(),
    package = NULL,
    selection_method=NULL,
    des_func=NULL,
    alpha_des = NULL,
    weight_const = NULL,
    error_power = NULL,
    actual_des_func=NULL,
    design = NULL,
    number_runs = NULL,
    completed_runs = NULL,
    pass_list = NULL,
    parallel = NULL,
    parallel_cores = NULL,
    parallel_cluster = NULL,
    initialize = function(func, D, L, b=NULL, batches=10, reps=5,
                          obj=c("nonadapt", "grad"),
                          #plot_after=c(), plot_every=c(),
                          #forces=c("old"),force_vals=c(0),
                          force_old=c(0), force_pvar=c(0),
                          n0=0, stage1batches=0,
                          save_output=F, func_string = NULL,
                          seed_start=as.numeric(Sys.time()),
                          design_seed_start=as.numeric(Sys.time()),
                          package="laGP",
                          selection_method='SMED',
                          design='sFFLHD',
                          des_func=NA, alpha_des=1, weight_const=0,
                          error_power=1,
                          actual_des_func=NULL,
                          pass_list=list() # List of things to pass to adapt concept for each
                          , folder_name,
                          parallel=FALSE, parallel_cores="detect"
                          ) {
      print('creating compad')
      self$func <- func
      self$D <- D
      self$L <- L
      if (is.null(b)) {
        b <- L
      }
      self$b <- b
      self$batches <- batches
      self$reps <- reps
      self$obj <- obj
      #self$forces <- forces
      #self$force_vals <- force_vals
      self$force_old <- force_old
      self$force_pvar <- force_pvar
      self$n0 <- n0
      self$stage1batches <- stage1batches
      self$save_output <- save_output
      self$seed_start <- seed_start
      self$design_seed_start <- design_seed_start
      self$package <- package
      self$selection_method <- selection_method
      self$design <- self$design
      self$des_func <- des_func
      self$alpha_des <- alpha_des
      self$weight_const <- weight_const
      self$error_power <- error_power
      self$actual_des_func <- actual_des_func
      self$pass_list <- pass_list
      self$parallel <- parallel
      self$parallel_cores <- parallel_cores
      if (self$parallel) { # For now assume using parallel package
        if (parallel_cores == "detect") {
          self$parallel_cores <- parallel::detectCores()
        } else if (parallel_cores == "detect-1") {
          detectCor <- parallel::detectCores()
          if (detectCor == 1) {
            stop("Only 1 core detected, can't do 'detect-1'")
          }
          self$parallel_cores <- detectCor - 1
        } else {
          self$parallel_cores <- parallel_cores
        }
      }
      if (is.null(func_string)) {
        if (is.character(func)) {func_string <- func}
        else if (length(func) == 1){func_string <- paste0(deparse(substitute(func)), collapse='')}
        else if (length(func) > 1) {func_string <- paste0('func',1:length(func))}
        else {stop("Function error 325932850")}
      }
      self$func_string <- func_string
      self$set_folder_name(folder_name=folder_name)

      if (any(is.function(func))) {

      }
      self$rungrid <- reshape::expand.grid.df(
                   data.frame(
                     func=func_string, func_string=func_string,
                     func_num=1:length(func), stringsAsFactors=FALSE
                   ),
                   data.frame(D),data.frame(L), data.frame(b),
                   data.frame(repl=1:reps,
                              seed=if(!is.null(seed_start)) seed_start+1:reps-1 else NA,
                              design_seed=if(!is.null(design_seed_start)) {
                                            design_seed_start+(1:reps-1)*1e5
                                          } else {NA}),
                   data.frame(reps),
                   data.frame(batches),
                   data.frame(obj, selection_method, des_func,
                              alpha_des, weight_const, error_power,
                              actual_des_func, #=deparse(substitute(actual_des_func)),
                              actual_des_func_num=1:length(actual_des_func),
                              design,
                              stringsAsFactors = F),
                   #data.frame(forces=forces,force_vals=force_vals),
                   data.frame(force_old,force_pvar),
                   data.frame(n0),
                   data.frame(stage1batches),
                   data.frame(package, stringsAsFactors = FALSE)
                   #data.frame(selection_method, des_func, stringsAsFactors = FALSE)
                )
      #self$multiple_option_columns <- c()
      #self$rungrid$Group <- ""
      group_names <- c()

      # These are columns to use to split into groups
      for (i_input in c('func_string', 'D', 'L', 'b', 'reps', 'batches', 'obj',
                        'force_old', 'force_pvar', 'n0','package',
                        'selection_method', 'design', 'des_func')) {
        evalparsei <- eval(parse(text=i_input))
        if (length(evalparsei) > 1 && !all(evalparsei == evalparsei[1])) {
          #self$rungrid$Group <- paste(self$rungrid$Group, self$rungrid[,i_input])
          group_names <- c(group_names, i_input)
        }
      }
      if (length(group_names) == 0) {
        stop("All inputs are length one, need at least one with multiple values #59102")
      }

      group_cols <- sapply(group_names, function(gg){paste0(gg,'=',self$rungrid[,gg])})
      self$rungrid$Group <- apply(group_cols, 1, function(rr){paste(rr, collapse=',')})
      self$rungridlist <- as.list(
        self$rungrid[, !(colnames(self$rungrid) %in%
                           c("func_string", "func_num", "repl","reps","batches",
                             "seed","Group", "actual_des_func_num"))])
      self$rungridlist$func <- c(func)[self$rungrid$func_num]
      self$rungridlist$actual_des_func <- c(actual_des_func)[self$rungrid$actual_des_func_num]
      self$number_runs <- nrow(self$rungrid)
      self$completed_runs <- rep(FALSE, self$number_runs)
      #self$outrawdf <- data.frame()
    },
    set_folder_name = function(folder_name, add_timestamp=FALSE) {
      if (missing(folder_name)) {
        folderTime0 <- gsub(" ","_", Sys.time())
        folderTime <- gsub(":","-", folderTime0)
        t1 <- c(self$func_string,"_D=",self$D,"_L=",self$L,"_b=",self$b,
                "_B=",self$batches,"_R=",self$reps,"_n0=",self$n0,
                # "_Fold=",self$force_old,"_Fpvar=",self$force_pvar,
                "_s1b=",self$stage1batches)
        if (!is.null(self$seed_start)) {t1 <- c(t1,"_","S=",self$seed_start)}
        if (add_timestamp) {t1 <- c(t1,"_",folderTime)}
        folder_name <- paste0(t1, collapse = "")
      }
      self$folder_name <- folder_name
      self$folder_path <- paste0("./compare_adaptconcept_output/",self$folder_name)
    },
    create_output_folder = function(add_timestamp = FALSE) {
      # if (self$folder_created) {return(invisible(self))}
      if (!dir.exists(self$folder_path)) {
        dir.create(path = self$folder_path)
        # self$folder_created = TRUE
      } else {
        # stop("Error, folder already exists but folder_created==FALSE")
      }
      invisible(self)
    },
    run_all = function(redo = FALSE, noplot=FALSE, save_every=FALSE, run_order,
                       parallel=self$parallel, parallel_temp_save=FALSE) {
      if (!redo) { # Only run ones that haven't been run yet
        to_run <- which(self$completed_runs == FALSE)
      } else {
        to_run <- 1:self$number_runs
      }
      # Set run order
      if (missing(run_order)) { # random for parallel for load balancing
        if (self$parallel) {run_order <- "random"}
        else {run_order <- "inorder"}
      }
      if (run_order == "inorder") {} # Leave it in order
      else if (run_order == "reverse") {to_run <- rev(to_run)}
      else if (run_order == "random") {to_run <- sample(to_run)}
      else {stop("run_order not recognized #567128")}
      # Run, handle parallel differently
      if (parallel) {
        if (is.null(self$parallel_cluster)) {
          self$parallel_cluster <- parallel::makeCluster(spec = self$parallel_cores, type = "SOCK")
        }
        if (parallel_temp_save) {self$create_output_folder()}
        parout <- parallel::clusterApplyLB(
          cl=self$parallel_cluster,
          to_run,
          function(ii){
            tempout <- self$run_one(ii, is_parallel=TRUE, noplot=TRUE)
            if (parallel_temp_save) {
              saveRDS(object=tempout, file=paste0(self$folder_path,"/parallel_temp_output_",ii,".rds"))
            }
            tempout
          })
        lapply(parout, function(oneout) {do.call(self$add_result_of_one, oneout)})
        parallel::stopCluster(self$parallel_cluster)
        self$parallel_cluster <- NULL
        if (parallel_temp_save) {
          sapply(to_run,
                 function(ii) {
                   unlink(paste0(self$folder_path,"/parallel_temp_output_",ii,".rds"))
                 })
          self$delete_save_folder_if_empty()
        }
      } else {
        # sapply(to_run,function(ii){self$run_one(ii, noplot=noplot)})
        for (ii in to_run) {
          self$run_one(ii, noplot=noplot)
          if (save_every) {self$save_self()}
        }
      }
      self$postprocess_outdf()
      invisible(self)
    },
    run_one = function(irow=NULL, save_output=self$save_output, noplot=FALSE, is_parallel=FALSE) {
      if (is.null(irow)) { # If irow not given, set to next not run
        if (any(self$completed_runs == FALSE)) {
          irow <- which(self$completed_runs == 0)[1]
        } else {
          stop("irow not given and all runs completed")
        }
      } else if (length(irow) > 1) { # If more than one, run each separately
        sapply(irow, function(ii){self$run_one(irow=ii, save_output=save_output)})
        return(invisible(self))
      } else if (self$completed_runs[irow] == TRUE) {
        warning("irow already run, will run again anyways")
      }
      cat("Running ", irow, ", completed ", sum(self$completed_runs),"/",
          length(self$completed_runs), " ",
          format(Sys.time(), "%a %b %d %X %Y"), "\n", sep="")
      row_grid <- self$rungrid[irow, ] #rungrid row for current run
      if (!is.na(row_grid$seed)) {set.seed(row_grid$seed)}
      #if (is.function(row_grid$func)) {}#funci <- self$func}
      #else if (row_grid$func == "RFF") {row_grid$func <- RFF_get(D=self$D)}
      #else {stop("No function given")}

      # If parallel, need to source file
      if (is_parallel) {
        source("adaptconcept2_sFFLHD_R6.R")

        # Save a start file
        STARTED_filepath <- paste0(self$folder_path,"/STARTED_", irow, ".csv")
        cat(timestamp(), "\n",
            file=STARTED_filepath)
      }

      input_list <- c(lapply(self$rungridlist, function(x)x[[irow]]), self$pass_list)
      u <- do.call(adapt.concept2.sFFLHD.R6$new, input_list)

      # Run and time it
      start_time <- Sys.time()
      systime <- system.time(u$run(row_grid$batches,noplot=noplot))
      end_time <- Sys.time()

      newdf0 <- data.frame(batch=u$stats$iteration, mse=u$stats$mse,
                           pvar=u$stats$pvar, pamv=u$stats$pamv,
                           pred_intwerror=u$stats$intwerror,
                           actual_intwerror=u$stats$actual_intwerror,
                           actual_intwvar=u$stats$actual_intwvar,
                           do.call(rbind, lapply(u$stats$actual_intwquants, function(df) {data.frame(actual_intabserquants       =t((df$abserrquant)))})),
                           do.call(rbind, lapply(u$stats$actual_intwquants, function(df) {data.frame(actual_intsqerrquants       =t((df$sqerrquant)))})),
                           do.call(rbind, lapply(u$stats$actual_intwquants, function(df) {data.frame(actual_preddesabserrquants  =t((df$preddesabserrquant)))})),
                           n=u$stats$n,
                           #obj=row_grid$obj,
                           num=paste0(row_grid$obj,row_grid$repl),
                           time = systime[3], #repl=row_grid$repl,
                           start_time=start_time, end_time=end_time,
                           run_number=irow,
                           #force_old=row_grid$force_old, force_pvar=row_grid$force_pvar,
                           force2=paste0(row_grid$force_old, '_', row_grid$force_pvar),

                           row.names=NULL,
                           stringsAsFactors = FALSE
      )
      newdf1 <- cbind(row_grid, newdf0, row.names=NULL)
      u$delete()
      if (is_parallel) {
        # Delete STARTED file
        if (file.exists(STARTED_filepath)) {
          unlink(STARTED_filepath)
        }
        # Return result
        return(list(irow=irow, newdf1=newdf1))
      }
      self$add_result_of_one(irow=irow, newdf1=newdf1)
      invisible(self)
    },
    add_result_of_one = function(irow, newdf1, save_output=self$save_output) {

      if (nrow(self$outrawdf) == 0) {
        # If outrawdf not yet created, created blank df with
        #   correct names and size
        self$outrawdf <- as.data.frame(
                           matrix(data=NA,
                                  nrow=nrow(self$rungrid) * self$batches,
                                  ncol=ncol(newdf1)
                                  )
                           )
        colnames(self$outrawdf) <- colnames(newdf1)
        for (i in 1:ncol(self$outrawdf)) {class(self$outrawdf[,i]) <- class(newdf1[1,i])}
      }
      self$outrawdf[((irow-1)*self$batches+1):(irow*self$batches), ] <- newdf1

      if (save_output) {
        if (file.exists(paste0(self$folder_path,"/data_cat.csv"))) { # append new row
          write.table(x=newdf1, file=paste0(self$folder_path,"/data_cat.csv"),
                      append=T, sep=",", col.names=F)
        } else { #create file
          self$create_output_folder()
          write.table(x=newdf1, file=paste0(self$folder_path,"/data_cat.csv"),
                      append=F, sep=",", col.names=T)
        }
      }
      self$completed_runs[irow] <- TRUE
    },
    postprocess_outdf = function(save_output=self$save_output) {
      self$outdf <- self$outrawdf
      self$outdf$rmse <- sqrt(ifelse(self$outdf$mse>=0, self$outdf$mse, 1e-16))
      self$outdf$prmse <- sqrt(ifelse(self$outdf$pvar>=0, self$outdf$pvar, 1e-16))
      self$enddf <- self$outdf[self$outdf$batch == self$batches,]
      # Want to get mean of these columns across replicates
      meanColNames <- c("mse","pvar","pamv","rmse","prmse","pred_intwerror",
                        "actual_intwerror", "actual_intwvar")
      # Use these as ID, exclude repl, seed, and num and time
      splitColNames <- c("func","func_string","func_num","D","L","b",
                         "reps","batches",
                         "force_old","force_pvar","force2",
                         "n0","obj", "batch", "n", "Group","package",
                         "selection_method", "design", "des_func",
                         "actual_des_func_num", "alpha_des", "weight_const",
                         "error_power")
      self$meandf <- plyr::ddply(
                       self$outdf,
                       splitColNames,
                       function(tdf){
                         colMeans(tdf[,meanColNames])
                       }
                     )
      # Get warning if any NA in self$outdf[,meanColNames]
      # Give message so it's clear where it comes from
      if (any(apply(self$outdf[,meanColNames], 2, is.nan))) {
        message(paste0("Some values in $outdf are NaN,",
                       " warning comes from making meanlogdf #92538"))
      }
      self$meanlogdf <- plyr::ddply(
                      self$outdf,
                      splitColNames,
                      function(tdf){
                        exp(colMeans(log(tdf[,meanColNames])))
                      }
      )
      self$endmeandf <- plyr::ddply(
        self$enddf,
        splitColNames,
        function(tdf){
          c(
            colMeans(tdf[,meanColNames])
            , setNames(c(summary(tdf$actual_intwerror),
                         sd(tdf$actual_intwerror)),
                       paste("actual_intwerror",
                             c("Min", "Q1","Med","Mean","Q3","Max","sd"),
                             sep = '_'))
            , setNames(c(summary(tdf$actual_intwvar),
                         sd(tdf$actual_intwvar)),
                       paste("actual_intwvar",
                             c("Min", "Q1","Med","Mean","Q3","Max","sd"),
                             sep = '_'))
          )
        }
      )

      if (self$save_output) {write.csv(self$outdf, paste0(self$folder_path,"/data.csv"))}
      if (self$save_output) {self$save_self()}
      invisible(self)
    },
    plot_MSE_over_batch = function(save_output = self$save_output, legend_labels=NULL) {
      if (save_output) {
        png(filename = paste0(self$folder_path,"/plotMSE.png"),
            width = 480, height = 480)
      }
      p <- ggplot(data=self$outdf, aes(x=batch, y=mse, group = interaction(num,Group), colour = Group)) +
        geom_line() +
        geom_line(inherit.aes = F, data=self$meanlogdf,
                  aes(x=batch, y=mse, colour = Group, size=3, alpha=.5)) +
        geom_point() +
        scale_y_continuous(trans="log", breaks = base_breaks()) + #scale_y_log10() +
        xlab("Batch") + ylab("MSE") + guides(size=FALSE, alpha=FALSE)
      if (!is.null(legend_labels)) {
        p <- p + scale_color_hue(labels=legend_labels)
      }
      print(p)
      if (save_output) {dev.off()}
      invisible(self)
    },
    plot_AWE_over_batch = function(save_output = self$save_output) {
      if (save_output) {
        png(filename = paste0(self$folder_path,"/plot_actual_intwerror.png"),
            width = 480, height = 480)
      }
      print(
        ggplot(data=self$outdf, aes(x=batch, y=actual_intwerror,
                                    group = interaction(num,Group),
                                    colour = Group)) +
          geom_line() +
          geom_line(inherit.aes = F,
                    data=self$meanlogdf, aes(x=batch, y=actual_intwerror,
                                             colour = Group, size=3, alpha=.5)
                    ) +
          geom_point() +
          # scale_y_log10(breaks = base_breaks()) + #pretty(self$outdf$actual_intwerror, n=5)) +
          scale_y_continuous(trans="log", breaks = base_breaks()) +
          #pretty(self$outdf$actual_intwerror, n=5)) +
          xlab("Batch") + ylab("actual_intwerror") + guides(size=FALSE, alpha=FALSE)
      )
      if (save_output) {dev.off()}
      invisible(self)
    },
    plot_AWE_over_group = function(save_output = self$save_output, boxpl=TRUE, logy=TRUE) {

      if (save_output) {
        png(filename = paste0(self$folder_path,"/plot_actual_intwerror_boxplot.png"),
            width = 480, height = 480)
      }
      p1 <- ggplot(data=self$enddf,
                   aes(x=Group, y=actual_intwerror, colour = Group)
            )# +  geom_jitter(width=.1)
      if (boxpl) {p1 <- p1 + geom_boxplot()}
      p1 <- p1 + geom_jitter(width=.1)
      if (logy) {
        p1 <- p1 + #scale_y_log10() +
          scale_y_continuous(trans="log", breaks = base_breaks())
      }
      print(p1)
      if (save_output) {dev.off()}
      invisible(self)
    },
    plot_MSE_PVar = function(save_output = self$save_output) {
      if (save_output) {
        png(filename = paste0(self$folder_path,"/plotMSEPVar.png"),
            width = 480, height = 480)
      }
      print(
        ggplot(data=self$outdf, aes(x=mse, y=pvar, group = interaction(num,Group), colour = Group)) +
          geom_line() + # Line for each rep
          geom_line(inherit.aes=F, data=self$meanlogdf, aes(x=mse, y=pvar, size=4, colour=Group), alpha=.5
                    ) +# Line for mean
          geom_point() + # Points for each rep
          geom_point(inherit.aes=F, data=self$enddf,
                     aes(x=mse, y=pvar, size=4, colour=Group)
                     ) + # Big points at end
          geom_abline(intercept = 0, slope = 1) + # y=x line, expected for good model
          xlab("MSE") + ylab("PVar") + guides(size=FALSE) +
          scale_x_log10() + scale_y_log10()
      )
      if (save_output) {dev.off()}
      invisible(self)
    },
    plot_RMSE_PRMSE = function(save_output = self$save_output) {
      if (save_output) {
        png(filename = paste0(self$folder_path,"/plotRMSEPRMSE.png"),
            width = 480, height = 480)
      }
      print(
        ggplot(data=self$outdf, aes(x=rmse, y=prmse, group = interaction(num,Group), colour = Group)) +
          geom_line() + # Line for each rep
          geom_line(inherit.aes=F, data=self$meanlogdf,
                    aes(x=rmse, y=prmse, size=4, colour = Group), alpha=.5
                    ) +# Line for mean
          geom_point() + # Points for each rep
          geom_point(inherit.aes=F, data=self$enddf, aes(x=rmse, y=prmse, size=4, colour = Group)
                     ) + # Big points at end
          geom_abline(intercept = 0, slope = 1) + # y=x line, expected for good model
          xlab("RMSE") + ylab("PRMSE") + guides(size=FALSE) +
          scale_x_log10() + scale_y_log10()
      )
      if (save_output) {dev.off()}
      invisible(self)
    },
    plot = function(save_output = self$save_output) {
      self$plot_MSE_PVar(save_output=save_output)
      self$plot_RMSE_PRMSE(save_output=save_output)
      self$plot_MSE_over_batch(save_output=save_output)
      self$plot_AWE_over_batch(save_output=save_output)
      invisible(self)
    },
    plot_run_times = function() {
      print(
        ggplot2::ggplot(self$outrawdf) +
          ggplot2::geom_segment(
            ggplot2::aes(x=start_time, xend=end_time,
                         y=run_number, yend=run_number)) +
          ggplot2::xlab("Start and end time") +
          ggplot2::ylab("Run number")
      )
      invisible(self)
    },
    save_self = function(object_name="object") { # Save compare R6 object
      file_path <- paste0(self$folder_path,"/",object_name,".rds")
      cat("Saving to ", file_path, "\n")
      # self$create_save_folder_if_nonexistent()
      self$create_output_folder()
      saveRDS(object = self, file = file_path)
      invisible(self)
    },
    # create_save_folder_if_nonexistent = function() {
    #   if (!dir.exists(self$folder_path)) {
    #     dir.create(self$folder_path)
    #   }
    # },
    delete_save_folder_if_empty = function() {
      if (length(list.files(path=self$folder_path, all.files = TRUE, no.. = TRUE)) == 0) {
        unlink(self$folder_path, recursive = TRUE)
      } else {
        # stop("Folder is not empty")
      }
      invisible(self)
    },
    recover_parallel_temp_save = function(save_if_any_recovered=TRUE) {
      # Read in and save
      any_recovered <- FALSE
      for (ii in 1:nrow(self$rungrid)) {
        # Check for file
        file_ii <- paste0(self$folder_path,"/parallel_temp_output_",ii,".rds")
        if (file.exists(file_ii)) {
          # Read in
          oneout <- readRDS(file=file_ii)
          do.call(self$add_result_of_one, oneout)
          # Delete it
          unlink(file_ii)
          any_recovered <- TRUE
        }
      }
      if (any_recovered && save_if_any_recovered) {
        self$save_self()
      }
      self$delete_save_folder_if_empty()
      invisible(self)
    },
    parallel_efficiency = function() {
      sum(self$enddf$time) /
        as.numeric(max(self$enddf$end_time) - min(self$enddf$start_time),
                   unit='secs')
    }
    # load = function() {
    #   self$outdf = read.csv()
    #   self$postprocess_outdf()
    #   invisible(self)
    # }
  )
)

if (F) {
  ca1 <- compare.adaptR6$new(func=gaussian1, D=2, L=3, n0=6)$run_all()$plot()
  ca1$run()

  ca1 <- compare.adaptR6$new(func=add_null_dims(banana,2), D=4, L=4,
                             obj=c("nonadapt", "grad","gradpvaralpha"),
                             batches=10, reps=5, n0=10)$run_all()$plot()


  ca1 <- compare.adaptR6$new(func=banana, D=2, L=4,
                             obj=c("nonadapt", "grad","gradpvaralpha"),
                             batches=20, reps=3, n0=10, package=c("laGP")
                             )$run_all()$plot()


  # For desirability
  ca1 <- compare.adaptR6$new(func=gaussian1, D=2, L=3, n0=6, obj="desirability",
                             selection_method=c('max_des', 'SMED'),
                             des_func=c('des_func_relmax', NA))$run_all()$plot()
  ca1 <- compare.adaptR6$new(func=banana, D=2, L=4, n0=20,
                             obj=c("func","desirability"),
                             selection_method=c('SMED', 'max_des_red'),
                             des_func=c('NA', 'des_func_relmax'), alpha_des=1e3,
                             actual_des_func=c('NA',
                               'get_actual_des_func_relmax(f=banana, fmin=0, fmax=1)'),
                             package="laGP")$run_all()$plot()
  ca1 <- compare.adaptR6$new(func=banana, reps=3, batches=3, D=2, L=4, n0=20,
                             obj=c("func","desirability"),
                             selection_method=c('SMED', 'max_des_red'),
                             des_func=c('NA', 'des_func_relmax'), alpha_des=1e3,
                             actual_des_func=c(get_actual_des_func_relmax(f=banana, fmin=0, fmax=1)),
                             package="laGP")$run_all()$plot()
  ca1 <- compare.adaptR6$new(func=banana, reps=10, batches=10, D=2, L=4, n0=20,
                             obj=c("func","desirability"),
                             selection_method=c('SMED', 'max_des_red'),
                             des_func=c('NA', 'des_func_relmax'), alpha_des=1e3,
                             actual_des_func=c(get_actual_des_func_relmax(f=banana, fmin=0, fmax=1)),
                             package="laGP")$run_all()$plot()
  ca1 <- compare.adaptR6$new(func=banana, reps=2, batches=5, D=2, L=4, n0=20,
                             obj=c("func","desirability"), selection_method=c('SMED', 'max_des_red'),
                             des_func=c('NA', 'des_func_relmax'), alpha_des=1e3,
                             actual_des_func=c(get_actual_des_func_relmax(f=banana, fmin=0, fmax=1)),
                             package="laGP_GauPro")$run_all()$plot()
  ca1 <- compare.adaptR6$new(func=borehole, reps=2, batches=5, D=8, b=4, L=8,
                             n0=20, obj=c("func","desirability"),
                             selection_method=c('SMED', 'max_des_red'),
                             des_func=c('NA', 'des_func_relmax'), alpha_des=1e2,
                             actual_des_func=c(actual_des_func_relmax_borehole),
                             package="laGP_GauPro")$run_all()$plot()
  ca1 <- compare.adaptR6$new(func_string='otl',func=OTL_Circuit, reps=2,
                             batches=5, D=6, b=4, L=8, n0=20,
                             obj=c("func","desirability"),
                             selection_method=c('SMED', 'max_des_red'),
                             des_func=c('NA', 'des_func_relmax'), alpha_des=1e3,
                             actual_des_func=NULL, package="laGP_GauPro"
                             )$run_all()$plot()
  ca1 <- compare.adaptR6$new(func=banana, reps=2, batches=2, D=2, L=2, n0=15,
                             obj=c("nonadapt","func","desirability"),
                             selection_method=c("nonadapt",'SMED', 'max_des_red'),
                             des_func=c('NA','NA', 'des_func_relmax'), alpha_des=1e3,
                             actual_des_func='get_actual_des_func_relmax(f=banana, fmin=0, fmax=1)',
                             package="laGP_GauPro", seed=33123)$run_all()$plot()
  ca1$plot_AWE_over_batch()
  # Show summary of actual_intwerror
  plyr::ddply(ca1$enddf, .(Group), function(grp) {summary(grp$actual_intwerror)})
}
