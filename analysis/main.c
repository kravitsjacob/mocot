#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <time.h>
#include <math.h>
#include <mpi.h>
#include <julia.h>
#include "borg_src/borgms.h"

//JULIA_DEFINE_FAST_TLS

#define PI 3.14159265358979323846

int ndecs = 6;
int nobjs = 9;

void simulation_wrapper(double* decs, double* objs, double* consts)
{
   // Setup
   int i;
   jl_value_t* args[ndecs];

   // Initialize function
   jl_module_t *module = (jl_module_t*)jl_eval_string("MOCOT");

   // Initialize simulation function
   jl_function_t *func = jl_get_function(module, "borg_simulation_wrapper");

   // Call julia function
   for(i = 0; i < ndecs; i++)
   {
        jl_value_t *dec = jl_box_float64(decs[i]);
        args[i] = dec;
   }
   jl_array_t *ret = (jl_array_t*)jl_call(func, args, ndecs);

   // Set objectives values
   double *objData = (double*)jl_array_data(ret);
   for(i = 0; i < nobjs; i++)
   {
        objs[i] = objData[i];
   }
}


int main(int argc, char* argv[])
{
   // Setup C
	int i, j;
	int rank;
	char runtime[256];
   FILE *fp;

   // Setup julia
   jl_init();
   jl_eval_string("using MOCOT");

	// Simulation setup
   BORG_Algorithm_ms_max_evaluations(1000);
   BORG_Algorithm_output_frequency(10);
	BORG_Algorithm_ms_startup(&argc, &argv);

	// Setting up problem
	BORG_Problem problem = BORG_Problem_create(ndecs, nobjs, 0, simulation_wrapper);

   // Decision bounds
   // w_with_coal
   BORG_Problem_set_bounds(problem, 0, 0.0, 0.5);
   // w_con_coal
   BORG_Problem_set_bounds(problem, 1, 0.0, 5.0);
   // w_with_ng
   BORG_Problem_set_bounds(problem, 2, 0.0, 0.5);
   // w_con_ng
   BORG_Problem_set_bounds(problem, 3, 0.0, 0.5);
   // w_with_nuc
   BORG_Problem_set_bounds(problem, 4, 0.0, 0.5);
   // w_con_nuc
   BORG_Problem_set_bounds(problem, 5, 0.0, 0.5);

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
   sprintf(runtime, "analysis/io/outputs/states/runtime.txt");
   BORG_Algorithm_output_runtime(runtime);

   // Seed the random number generator.
   BORG_Random_seed(1008);

   // Run the parent-child Borg MOEA on the problem.
   BORG_Archive result = BORG_Algorithm_ms_run(problem);

   // Print the Pareto optimal solutions to the screen.
   if (result != NULL)
   {
      fp = fopen("analysis/io/outputs/front/front.txt", "w+");
      BORG_Archive_print(result, fp);
      BORG_Archive_destroy(result);
      fclose(fp);
   }

	// Shutdown the parallel processes and exit.
	BORG_Algorithm_ms_shutdown();
	BORG_Problem_destroy(problem);
	return EXIT_SUCCESS;
}
