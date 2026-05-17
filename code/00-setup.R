# after cloning the repository, you should see the following files in the code folder:
# - renv.lock
# - .Rprofile
# renv/activate.R
# renv/settings.json

# you will need to install the 'yaml' package:
options(repos = c(CRAN = "https://cloud.r-project.org"))
install.packages("yaml")

# run the following code to recreate the R environment used to conduct the analyses:
# If prompted, select 1: Activate the project and use the project library. 
# Then run renv::restore() again. It might take a few minutes to finish installing all packages.
renv::restore()

# create a .Renviron file with the DSN needed to load the data and the project paths.
# update the values below, then run this block.
lines <- c(
  "DSN='your_DSN'",
  "PROJECT_ROOT='/path/to/your/repo'",
  "OUTPUT_DIR='/path/to/your/repo/output'",
  "RESULTS_DIR='/path/to/your/repo/results'"
)
writeLines(lines, ".Renviron")

# you can confirm that it worked by running the following line:
Sys.getenv("DSN")