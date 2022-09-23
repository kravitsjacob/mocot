MPICC = mpicc
GCC = gcc
CFLAGS = -O3
LIBS = -lm
JULIAPATH = /bin/julia/julia-1.8.1
JULIAFLAGS = -I$(JULIAPATH)/include/julia -L$(JULIAPATH)/lib -Wl,-rpath,$(JULIAPATH)/lib -ljulia
JULIAPATH_SLURM = /curc/sw/julia/1.6.6
JULIAFLAGS_SLURM = -I$(JULIAPATH_SLURM)/include/julia -L$(JULIAPATH_SLURM)/lib -Wl,-rpath,$(JULIAPATH_SLURM)/lib -ljulia

single:
	$(GCC) -o single_simulation.exe single_simulation.c $(JULIAFLAGS)

optimization:
	$(MPICC) $(CFLAGS) -o optimization.exe optimization.c borg_src/borgms.c borg_src/mt19937ar.c $(LIBS) $(JULIAFLAGS)

slurm:
	$(MPICC) $(CFLAGS) -o optimization.exe optimization.c borg_src/borgms.c borg_src/mt19937ar.c $(LIBS) $(JULIAFLAGS_SLURM)
 
clean:
	rm optimization.exe single_simulation.exe