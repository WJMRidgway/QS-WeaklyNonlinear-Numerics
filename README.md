# QS-WeaklyNonlinear-Numerics

> Numerical code accompanying [*A Weakly Nonlinear Theory for Pattern Formation in Structured Models with Localized Solutions*](https://doi.org/10.48550/arXiv.2510.20781).

This repository contains finite-element solvers for the chemically structured quorum-sensing model considered in the paper. The implementation uses quadratic Lagrange elements and the open-source [oomph-lib](https://github.com/oomph-lib/oomph-lib) finite-element library. The time-dependent solver uses adaptive second-order backward differentiation (BDF2).

## Installation

The two directories contain independent oomph-lib drivers and each includes a `Makefile.am` specifying its source files and executable. These files are intended for the **Autotools-based version of oomph-lib**, following the same approach as the [oomph-lib user-driver installation instructions](https://jondea.github.io/oomph-lib/doc/the_distribution/html/index.html).

First install and configure an Autotools-based oomph-lib distribution, with MPI support if running in parallel. A C++ compiler, GNU Autotools, and an MPI implementation are required for the corresponding build and parallel runs. After installing oomph-lib, copy the `steady_state_continuation` and `unsteady` folders into its `user_drivers` directory and rerun `autogen.sh` from the top-level oomph-lib directory. 

This builds the executables `steady_solve` and `unsteady_density` in their respective directories. If your oomph-lib distribution has not already been configured and built, follow its installation instructions before compiling the drivers. The `Makefile.am` files are **not standalone Makefiles**: running `make` in a freshly downloaded copy of this repository will not work without integrating the drivers into the appropriate oomph-lib build system.

**Compatibility note:** Current oomph-lib releases use CMake rather than Autotools. The supplied `Makefile.am` files target the older Autotools build system; a CMake-based installation would require corresponding `CMakeLists.txt` files or a conversion of the build configuration. The compilation procedure above has not been independently tested with a fresh oomph-lib installation.

## Usage examples

### `steady_state_continuation/`

This directory contains the steady-state solver `steady_solve`. It computes stationary solutions using Newton's method and traces nonuniform solution branches using pseudo-arclength continuation in `D1_p_star`, the derivative of the motility coefficient at the spatially homogeneous equilibrium.

The scripts `run.sh` and `restart.sh` generate input parameter files for selected values of `m` (the prescribed mean population density) and launch MPI runs. The values of the physical and numerical parameters, along with the result directories and number of processes, can be modified in these scripts.

Once compiled, the executable can also be run directly from `steady_state_continuation/`, using a parameter file with the assignments shown in `run.sh`:

```bash
mkdir -p RESULT0
mpirun -np 8 ./steady_solve input.dat RESULT0/
```

The steady-state parameter file requires the following 18 entries: `D2`, `beta`, `alpha`, `D1_star`, `D1_p_star`, `D_inf_0`, `Lu`, `Lx`, `a`, `L`, `K`, `lambda`, `m`, `epsilon`, `Nu_density`, `Nu_helm`, `Nx`, and `rho_eval`. The final four parameters specify the discretization and the spatial location at which the population density is evaluated for the bifurcation diagram.

**Initial conditions:** The supplied `run.sh` and `restart.sh` include an optional `--IC-file` argument pointing to `IC_rho_Dp_phase2/`. This directory is not included in the repository. You can create the required files from a previous numerical solution as described in [Preparing initial-condition files](#preparing-initial-condition-files). Alternatively, omit `--IC-file` to use the initial condition defined in `GlobalParams::get_IC()` in `steady_solve.cc`, as in the command above. Convergence to a particular nonuniform branch may depend on the initial condition.

The maximum pseudo-arclength step size, `ds_max`, and the initial continuation direction are set in `steady_solve.cc`. Decreasing `ds_max` may improve resolution or help avoid jumps between solution branches.

### `unsteady/`

This directory contains `unsteady_density`, which solves the time-dependent problem using adaptive BDF2 time stepping. After compiling, the program can be run from `unsteady/` with a prepared input file and output directory:

```bash
mkdir -p RESULT0
mpirun -np 8 ./unsteady_density input.dat RESULT0/
```

The time-dependent solver requires 20 parameter assignments. Most are shared with the steady solver, but it uses `rho_star` instead of `m`, requires `epsilon_t`, `t_max`, and `dt_out`, and does not use `rho_eval`. The full set is specified in `read_input_params_from_file()` in `unsteady_density.cc`; example values appear in `run.sh`. This time-dependent solver was used in the paper to test the linear stability of steady-state solutions, rather than for generating steady-state solutions.

The default initial condition is a spatially homogeneous state with a small random perturbation. The random-number generator is seeded from the current time, so repeated runs need not produce identical perturbations. An initial condition may instead be supplied using `--IC-file DIRECTORY/`, with the files described above. 

The provided `unsteady/run.sh` is an example of the parameter-generation and execution workflow, **not a self-contained run script**: it reads `Dp.in`, which is not included in this repository. To use it, supply that file or set `D1_p_star` directly. Both directories' scripts also include system-specific `module load` commands, MPI process counts and output paths that may need to be changed for your environment.

In the current implementation, the time-dependent solver records snapshots every ten time steps, rather than using `dt_out` as the active output criterion. The `dt_out` value is read from the input file but the time-based output condition is commented out in the source.

## Preparing initial-condition files

Both executables can initialize a new calculation from the output of an earlier run. The `--IC-file` option expects a directory containing two plain-text files:

- `density_ic.dat`, with three whitespace-separated columns `u x n` (the structured density).
- `AI_ic.dat`, with four whitespace-separated columns `u x c ubar` (the chemical concentration and first moment of the density).

**To generate these files, first run a simulation without `--IC-file`**, using the built-in initial condition. The steady-state solver writes `soln_densityYYY_on_procXXX.dat` and `soln_helmYYY_on_procXXX.dat`, where `YYY` is the solution index and `XXX` is the MPI process rank. In the steady solver, index `0` is the initial guess and index `1` is the output immediately following the initial Newton solve; later indices are snapshots of the continuation branch.

For example, to use the computed solution at index `1` from a run whose output is in `RESULT0/`, execute the following from the same working directory:

```bash
mkdir -p IC_FILES
cat RESULT0/soln_density1_on_proc*.dat > IC_FILES/density_ic.dat
cat RESULT0/soln_helm1_on_proc*.dat > IC_FILES/AI_ic.dat
```

Use all processor files belonging to the **same output index**. The source writes one row per finite-element node, so duplicate coordinate rows can occur at element boundaries; the initial-condition reader organizes the data by its `(u, x)` coordinates. No header row is required. The values should cover a regular grid and the two files must have compatible coordinate ranges.

To start another steady-state calculation from this solution (with a suitable `input.dat` and a new output directory):

```bash
mkdir -p RESULT1
mpirun -np 8 ./steady_solve input.dat RESULT1/ --IC-file IC_FILES/
```

The **trailing slash** on `IC_FILES/` is required: the program constructs filenames by appending `density_ic.dat` and `AI_ic.dat` directly to the supplied path. The data are interpolated onto the new finite-element grid, so the two runs need not have identical mesh resolutions, although their computational domains must be compatible. The same procedure can be applied to a snapshot from `unsteady_density` to initialize either program.

You may also construct these files directly from prescribed functions by tabulating `n(u,x)`, `c(u,x)` and `ubar(u,x)` on a regular `(u,x)` grid in the column formats above. A suitable initial condition is not necessarily a converged steady state; whether Newton's method converges to the desired branch depends on the initial guess.

## Output

Both programs write results to the output directory given as their second command-line argument. In parallel runs, each MPI process writes its own solution files:

- `soln_densityYYY_on_procXXX.dat`: the density solution, with columns `(u, x, n)`; `YYY` is the output index and `XXX` the processor rank.
- `soln_helmYYY_on_procXXX.dat`: the chemical-field solution, with columns `(u, x, c, ubar)`.
- `output.XXX`: diagnostic information for processor `XXX`.
- `params.dat`: physical and numerical parameters recorded by the program.

The steady-state solver additionally writes `bifurcation.dat`. Its three columns are `(D1_p_star, rho(0), rho(rho_eval))`, giving values along the computed branch. In steady runs, `YYY` indexes solution snapshots along the branch; in time-dependent runs, it indexes the snapshots whose times are recorded in `t_out.dat`.

For example, files from all processors corresponding to one output index can be combined with:

```bash
cat RESULT0/soln_density1_on_proc*.dat > soln_density1.dat
cat RESULT0/soln_helm1_on_proc*.dat > soln_helm1.dat
```

Each directory also contains a `combine_proc_output.sh` script. These scripts were written for particular simulation runs and contain hard-coded directory names, output indices, and processor ranges; adjust them before use.

The time-dependent program periodically writes restart files, which can be used to resume a calculation. Restart behaviour and the frequency of saving restart information are defined in the source code.

The examples above illustrate the numerical workflow, but they do not automate every parameter sweep or supply every initial condition used for the figures in the paper. Refer to the paper for the model equations and parameter definitions.

## License

Distributed under the GNU Lesser General Public License, version 2.1. See [LICENSE](LICENSE). Portions of the finite-element implementation are derived from oomph-lib and remain subject to its applicable copyright and licence terms.
