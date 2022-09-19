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

int ndecs = 6;
int nobjs = 9;

void simulation_wrapper(double* decs, double* objs, double* consts)
{
   // Setup
   int i;
   double args[ndecs];

   // Initialize function
   jl_module_t *module = (jl_module_t*)jl_eval_string("MOCOT");

   // Initialize simulation function
   jl_function_t *func = jl_get_function(module, "borg_simulation_wrapper");

   // Call julia function
   for(i = 0; i < ndecs; i++)
   {
        jl_value_t *dec = jl_box_float64(decs[i]);
        args[i] = dec
   }
    jl_value_t *jl_call(jl_function_t *f, jl_value_t **args, int32_t ndecs)

   // Set objectives values
   double *objData = (double*)jl_array_data(ret);
   for(i = 0; i < nobjs; i++)
   {
        objs[i] = objData[i];
   }
}


int main(int argc, char* argv[]) {
   // Setup C
	int i, j;
	int rank;
	char runtime[256];
   FILE *fp;

   // Setup julia
   jl_init();
   jl_eval_string("using MOCOT");

	// Simulation setup
   BORG_Algorithm_ms_max_evaluations(1);
   BORG_Algorithm_output_frequency(1);
	BORG_Algorithm_ms_startup(&argc, &argv);
	BORG_Algorithm_ms_max_time(0.1);

	// Setting up problem
	BORG_Problem problem = BORG_Problem_create(ndecs, nobjs, 0, simulation_wrapper);

   // Decisions
	for (j=0; j<ndecs; j++) {
		BORG_Problem_set_bounds(problem, j, 0.0, 1.0);
	}

   // Objectives
	for (j=0; j<nobjs; j++) {
		BORG_Problem_set_epsilon(problem, j, 0.1);
	}

	// Get the rank of this process.  The rank is used to ensure each
	// parallel process uses a different random seed.
	MPI_Comm_rank(MPI_COMM_WORLD, &rank);

   // Runtime file
   sprintf(runtime, "io/states/runtime.txt");
   BORG_Algorithm_output_runtime(runtime);

   // Seed the random number generator.
   BORG_Random_seed(1008);

   // Run the parent-child Borg MOEA on the problem.
   BORG_Archive result = BORG_Algorithm_ms_run(problem);

   // Print the Pareto optimal solutions to the screen.
   if (result != NULL)
   {
      fp = fopen("io/front/front.txt", "w+");
      BORG_Archive_print(result, fp);
      BORG_Archive_destroy(result);
      fclose(fp);
   }

	// Shutdown the parallel processes and exit.
	BORG_Algorithm_ms_shutdown();
	BORG_Problem_destroy(problem);
	return EXIT_SUCCESS;
}
