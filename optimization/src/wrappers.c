#include <stdio.h>
#include <julia.h>

extern int n_decs;
extern int n_objs;
extern int n_metrics;
extern int scenario_code;


void simulation_wrapper(double* decs, double* objs, double* metrics)
{
    // Setup
    int i;
    int n_args = n_decs + 3;
    jl_value_t* args[n_decs+2];

    // Decision arguments
    for(i = 0; i < n_decs; i++)
    {
        jl_value_t *dec = jl_box_float64(decs[i]);
        args[i] = dec;
    }

    // Assign return type to borg
    args[n_decs] = jl_box_int64(1);

    // Assign verbose to none
    args[n_decs+1] = jl_box_int64(0);

    // Assign scenario code
    args[n_decs+2] = jl_box_int64(scenario_code);

    // Call julia function
    jl_module_t *module = (jl_module_t*)jl_eval_string("MOCOT");
    jl_function_t *func = jl_get_function(module, "borg_simulation_wrapper");
    jl_array_t *ret = (jl_array_t*)jl_call(func, args, n_args);
    double *obj_metric_data = (double*)jl_array_data(ret);

    // Set objectives values
    for(i = 0; i < n_objs; i++)
    {
        objs[i] = obj_metric_data[i];
    }

    // Set metrics values
    for(i = 0; i < n_metrics; i++)
    {
        metrics[i] = obj_metric_data[n_objs + i];
    }
}