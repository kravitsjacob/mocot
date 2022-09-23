#include <stdio.h>
#include <julia.h>


int n_decs = 6;
int n_objs = 9;
int n_consts = 0;
int scenario_code;

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


int main(int argc, char* argv[])
{
    // Setup C
    double test_decs[n_decs];
    double test_objs[n_objs];
    double test_consts[n_consts];
    test_decs[0] = 0.1;
    test_decs[1] = 0.2;
    test_decs[2] = 0.3;
    test_decs[3] = 0.4;
    test_decs[4] = 0.5;
    test_decs[5] = 0.6;

    // Scenario code
    if (argc == 1){  // All generators scenario by default
        scenario_code = 1;
    }
    else if (argc == 2){
        sscanf(argv[1], "%i", &scenario_code);
    }

    // Setup julia
    jl_init();
    jl_eval_string("using analysis");

    simulation_wrapper(test_decs, test_objs, test_consts);

    printf("Objective 1 is %f \n", test_objs[0]);
    printf("Objective 2 is %f \n ", test_objs[1]);
    printf("Objective 3 is %f \n", test_objs[2]);
    printf("Objective 4 is %f \n", test_objs[3]);

	return 0;
}
