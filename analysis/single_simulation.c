#include <stdio.h>
#include <julia.h>


int ndecs = 6;
int nobjs = 9;
int nconsts = 0;

void simulation_wrapper(double* decs, double* objs, double* consts)
{
    // Setup
    int i;
    int nargs;
    jl_value_t* args[ndecs];

    // Initialize function
    jl_module_t *module = (jl_module_t*)jl_eval_string("analysis");

    // Initialize simulation function
    jl_function_t *func = jl_get_function(module, "borg_simulation_wrapper");

    // Decision arguments
    for(i = 0; i < ndecs; i++)
    {
            jl_value_t *dec = jl_box_float64(decs[i]);
            args[i] = dec;
    }

    // Assign output type to borg
    args[ndecs] = jl_box_int64(1);

    // Assign scenario type
    args[ndecs+1] = jl_box_int64(2);
    nargs = ndecs + 2;

    // Call julia function
    jl_array_t *ret = (jl_array_t*)jl_call(func, args, nargs);

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
    double decs[ndecs];
    double objs[nobjs];
    double consts[nconsts];
    decs[0] = 0.0;
    decs[1] = 0.0;
    decs[2] = 0.0;
    decs[3] = 0.0;
    decs[4] = 0.0;
    decs[5] = 0.0;

    // Setup julia
    jl_init();
    jl_eval_string("using analysis");

    simulation_wrapper(decs, objs, consts);

    printf("Objective 1 is %f", objs[0]);
    printf("Objective 2 is %f", objs[1]);

	return EXIT_SUCCESS;
}
