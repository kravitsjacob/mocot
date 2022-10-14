#include <stdio.h>
#include <julia.h>
#include "src/wrappers.h"

JULIA_DEFINE_FAST_TLS

int n_decs = 6;
int n_objs = 9;
int n_metrics = 4;
int scenario_code;


int main(int argc, char* argv[])
{
    // Setup C
    char scenario_code_char[2];
    double test_decs[n_decs];
    double test_objs[n_objs];
    double test_metrics[n_metrics];
    test_decs[0] = 0.1;
    test_decs[1] = 0.2;
    test_decs[2] = 0.3;
    test_decs[3] = 0.4;
    test_decs[4] = 0.5;
    test_decs[5] = 0.6;

    // Scenario code parsing
    if (argc == 1){  // All generators scenario by default
        strcpy(scenario_code_char, "1");
    }
    else if (argc == 2){
        strcpy(scenario_code_char, argv[1]);
    }
    sscanf(scenario_code_char, "%i", &scenario_code);

    // Setup julia
    jl_init();
    jl_eval_string("using MOCOT");

    simulation_wrapper(test_decs, test_objs, test_metrics);

    printf("Objective 1 is %f \n", test_objs[0]);
    printf("Objective 2 is %f \n ", test_objs[1]);
    printf("Objective 3 is %f \n", test_objs[2]);
    printf("Objective 4 is %f \n", test_objs[3]);

    printf("Metric 1 is %f \n", test_metrics[0]);
    printf("Metric 2 is %f \n", test_metrics[1]);
    printf("Metric 3 is %f \n", test_metrics[2]);
    printf("Metric 4 is %f \n", test_metrics[3]);

	return 0;
}
