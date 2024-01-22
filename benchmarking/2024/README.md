# 2024 Performance Portability Benchmarks

This directory contains work-in-progress scripts for a 2024 performance portability update.

## Structure

Each subdirectory corresponds to an application.
For each application, there are:

* Subdirectories with build and run scripts for each of the platforms in the study
* A results directory aggregating the output of the run scripts
* A common "plumbing" script `common.sh`

For the platforms included in the study, follow the steps below to build and run an application.
To use the scripts on a different platforms, paths and modules may need to be adjusted.

### Script Usage

Each platform subdirectory contains a `benchmark.sh` script, which is the only script you need to run.
The interface is the same to all `benchmark.sh` scripts across platforms, but the compilers and programming models available differ, e.g. the Intel compiler is only available on x86 platforms.
Select the platform you're running on, change to its directory, then run `./benchmark.sh -h` to see the available options.
Choose a programming model and compiler from the available options, then run the script:

1. Build the application:
    ```
    ./benchmark.sh build COMPILER MODEL
    ```
2. Run the application:
    ```
    ./benchmark.sh run COMPILER MODEL
    ```

Note that the command line is identical for the two steps above, except for the different subcommand (`build` vs `run`).

The result will be output in the current directory in a `.out` named after the application, the platform, and the chosen compiler and programming model.
