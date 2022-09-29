#include <stdio.h>
#include <julia.h>

extern int n_decs;
extern int n_objs;
extern int n_consts;
extern int scenario_code;


void simulation_wrapper(double* decs, double* objs, double* consts)
{
    // Setup
    int i;
    int n_args;
    jl_value_t* args[n_decs];

    // Initialize function
    jl_module_t *module = (jl_module_t*)jl_eval_string("MOCOT");

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