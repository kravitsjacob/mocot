#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <time.h>
#include <math.h>
#include <mpi.h>
#include <julia.h>
#include "borg_src/borgms.h"

JULIA_DEFINE_FAST_TLS

#define PI 3.14159265358979323846

int n_decs = 6;
int n_objs = 9;
int n_consts = 0;
int scenario_code;

// Simulation wrapper to call julia code from C
void simulation_wrapper(double* decs, double* objs, double* consts)
{
    // Setup
    int i;
    int n_args;
    jl_value_t* args[n_decs];

    // Initialize function
    jl_module_t *module = (jl_module_t*)jl_eval_string("analysis");

    // Initialize simulation function
    jl_function_t *func = jl_get_function(module, "borg_simulation_wrapper");

    // Decision arguments
    for(i = 0; i < n_decs; i++)
    {
        jl_value_t *dec = jl_box_float64(decs[i]);
        args[i] = dec;
    }

    // Assign output type to borg
    args[n_decs] = jl_box_int64(1);

    // Assign scenario type
    args[n_decs+1] = jl_box_int64(scenario_code);
    n_args = n_decs + 2;

    // Call julia function
    jl_array_t *ret = (jl_array_t*)jl_call(func, args, n_args);

    // Set objectives values
    double *objData = (double*)jl_array_data(ret);
    for(i = 0; i < n_objs; i++)
    {
        objs[i] = objData[i];
    }

}

// Set decision bounds based on scenario
void set_dec_bounds(BORG_Problem problem, int scenario_code)
{
    if (scenario_code == 1){
        // w_with_coal
        BORG_Problem_set_bounds(problem, 0, 0.0, 0.5);
        // w_con_coal
        BORG_Problem_set_bounds(problem, 1, 0.0, 5.0);
        // w_with_ng
        BORG_Problem_set_bounds(problem, 2, 0.0, 1.0);
        // w_con_ng
        BORG_Problem_set_bounds(problem, 3, 0.0, 1.0);
        // w_with_nuc
        BORG_Problem_set_bounds(problem, 4, 0.0, 1.0);
        // w_con_nuc
        BORG_Problem_set_bounds(problem, 5, 0.0, 1.0);
    }
    else if (scenario_code == 2){
        // w_with_coal
        BORG_Problem_set_bounds(problem, 0, 0.0, 0.5);
        // w_con_coal
        BORG_Problem_set_bounds(problem, 1, 0.0, 5.0);
        // w_with_ng
        BORG_Problem_set_bounds(problem, 2, 0.0, 1.0);
        // w_con_ng
        BORG_Problem_set_bounds(problem, 3, 0.0, 1.0);
        // w_with_nuc
        BORG_Problem_set_bounds(problem, 4, 0.0, 0.00001);
        // w_con_nuc
        BORG_Problem_set_bounds(problem, 5, 0.0, 0.00001);
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
    char path_to_front[50] = "analysis/io/outputs/front/scenario_0_front.txt";  // 0 replaced with scenario code
    char path_to_runtime[50] = "analysis/io/outputs/states/scenario_0_runtime.txt";  // 0 replaced with scenario code

    // Scenario code parsing
    if (argc == 1){  // All generators scenario by default
        strcpy(scenario_code_char, "1");
    }
    else if (argc == 2){
        strcpy(scenario_code_char, argv[1]);
    }
    sscanf(scenario_code_char, "%i", &scenario_code);

    // Setting output paths
    path_to_runtime[36] = scenario_code_char[0];
    path_to_front[35] = scenario_code_char[0];

    // Setup julia
    jl_init();
    jl_eval_string("using analysis");

	// Simulation setup
    BORG_Algorithm_ms_max_evaluations(10000);
    BORG_Algorithm_output_frequency(10);
	BORG_Algorithm_ms_startup(&argc, &argv);

    // Setting up problem
	BORG_Problem problem = BORG_Problem_create(n_decs, n_objs, n_consts, simulation_wrapper);

    // Set decision bounds
    set_dec_bounds(problem, scenario_code);

    // Objectives epsilons
    // f_gen
    BORG_Problem_set_epsilon(problem, 0, 10000.0);
    // f_cos_tot
   BORG_Problem_set_epsilon(problem, 1, 1000000.0);
    // f_with_peak
    BORG_Problem_set_epsilon(problem, 2, 1000000.0);
    // f_con_peak
    BORG_Problem_set_epsilon(problem, 3, 1000000.0);
    // f_with_tot
    BORG_Problem_set_epsilon(problem, 4, 100000000.0);
    // f_con_tot
    BORG_Problem_set_epsilon(problem, 5, 100000000.0);
    // f_disvi_tot
    BORG_Problem_set_epsilon(problem, 6, 1.0);
    // f_emit
    BORG_Problem_set_epsilon(problem, 7, 10.0);
    // f_ENS
    BORG_Problem_set_epsilon(problem, 8, 1.0);

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
        fp = fopen(path_to_front, "w+");
        BORG_Archive_print(result, fp);
        BORG_Archive_destroy(result);
        fclose(fp);
    }

	// Shutdown the parallel processes and exit.
	BORG_Algorithm_ms_shutdown();
	BORG_Problem_destroy(problem);
	return EXIT_SUCCESS;
}
