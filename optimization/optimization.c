#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <time.h>
#include <math.h>
#include <mpi.h>
#include <julia.h>
#include "src/borg/borgms.h"
#include "src/wrappers.h"

// Metrics quantify variable behavior but are not intended to be minimized. 
// Here, we modify the constraint functionality to not consider any violations.
// Thus, we can freely pass metrics as constraints and not worry about impacting solutions.
// We do this by commenting lines 506-510 and 617-620 in borg.c

JULIA_DEFINE_FAST_TLS

#define PI 3.14159265358979323846

int n_decs = 6;
int n_objs = 9;
int n_metrics = 4;
int scenario_code;

// Set decision bounds based on scenario
void set_dec_bounds(BORG_Problem problem, int scenario_code)
{
    if (scenario_code == 2){
        // w_with_coal
        BORG_Problem_set_bounds(problem, 0, 0.0, 2.0);
        // w_con_coal
        BORG_Problem_set_bounds(problem, 1, 0.0, 5.0);
        // w_with_ng
        BORG_Problem_set_bounds(problem, 2, 0.0, 2.0);
        // w_con_ng
        BORG_Problem_set_bounds(problem, 3, 0.0, 2.0);
        // w_with_nuc
        BORG_Problem_set_bounds(problem, 4, 0.0, 0.00001);
        // w_con_nuc
        BORG_Problem_set_bounds(problem, 5, 0.0, 0.00001);
    }
    else {
        // w_with_coal
        BORG_Problem_set_bounds(problem, 0, 0.0, 2.0);
        // w_con_coal
        BORG_Problem_set_bounds(problem, 1, 0.0, 5.0);
        // w_with_ng
        BORG_Problem_set_bounds(problem, 2, 0.0, 2.0);
        // w_con_ng
        BORG_Problem_set_bounds(problem, 3, 0.0, 2.0);
        // w_with_nuc
        BORG_Problem_set_bounds(problem, 4, 0.0, 2.0);
        // w_con_nuc
        BORG_Problem_set_bounds(problem, 5, 0.0, 2.0);
    }
}


int main(int argc, char* argv[])
{
    // Setup C
    int i, j;
    int rank;
    char scenario_code_char[2];
    char runtime[256];
    FILE *fp;
    char path_to_runtime[50] = "io/outputs/states/scenario_0_runtime.txt";  // 0 replaced with scenario code

    // Scenario code parsing
    if (argc == 1){  // All generators scenario by default
        strcpy(scenario_code_char, "1");
    }
    else if (argc == 2){
        strcpy(scenario_code_char, argv[1]);
    }
    sscanf(scenario_code_char, "%i", &scenario_code);

    // Setting output paths
    path_to_runtime[27] = scenario_code_char[0];

    // Setup julia
    jl_init();
    jl_eval_string("using MOCOT");

	// Simulation setup
    BORG_Algorithm_ms_max_evaluations(5000);
    BORG_Algorithm_output_frequency(100);
	BORG_Algorithm_ms_startup(&argc, &argv);

    // Setting up problem
	BORG_Problem problem = BORG_Problem_create(n_decs, n_objs, n_metrics, simulation_wrapper);

    // Set decision bounds
    set_dec_bounds(problem, scenario_code);

    // Objectives epsilons
    // f_gen
    BORG_Problem_set_epsilon(problem, 0, 100000.0);
    // f_cos_tot
    BORG_Problem_set_epsilon(problem, 1, 10000000.0);
    // f_with_peak
    BORG_Problem_set_epsilon(problem, 2, 100000000.0);
    // f_con_peak
    BORG_Problem_set_epsilon(problem, 3, 1000000.0);
    // f_with_tot
    BORG_Problem_set_epsilon(problem, 4, 1000000000.0);
    // f_con_tot
    BORG_Problem_set_epsilon(problem, 5, 10000000.0);
    // f_disvi_tot
    BORG_Problem_set_epsilon(problem, 6, 100000000.0);
    // f_emit
    BORG_Problem_set_epsilon(problem, 7, 10.0);
    // f_ENS
    BORG_Problem_set_epsilon(problem, 8, 0.1);

	// Get the rank of this process.  The rank is used to ensure each
	// parallel process uses a different random seed.
	MPI_Comm_rank(MPI_COMM_WORLD, &rank);

    // Runtime file
    BORG_Algorithm_output_runtime(path_to_runtime);

    // Seed the random number generator.
    BORG_Random_seed(1008);

    // Run the parent-child Borg MOEA on the problem.
    BORG_Archive result = BORG_Algorithm_ms_run(problem);

    // Print the Pareto optimal solutions to the screen.
    if (result != NULL)
    {
        BORG_Archive_destroy(result);
    }

	// Shutdown the parallel processes and exit.
	BORG_Algorithm_ms_shutdown();
	BORG_Problem_destroy(problem);
	return EXIT_SUCCESS;
}
