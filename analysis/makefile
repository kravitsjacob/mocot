MPICC = mpicc
CFLAGS = -O3
LIBS = -lm
JULIAPATH = /bin/julia/julia-1.8.1
JULIAFLAGS = -I$(JULIAPATH)/include/julia -L$(JULIAPATH)/lib -Wl,-rpath,$(JULIAPATH)/lib -ljulia
JULIAPATH_SLURM = /curc/sw/julia/1.6.6
JULIAFLAGS_SLURM = -I$(JULIAPATHALPINE)/include/julia -L$(JULIAPATHALPINE)/lib -Wl,-rpath,$(JULIAPATHALPINE)/lib -ljulia

compile:
	$(MPICC) $(CFLAGS) -o main.exe main.c borg_src/borgms.c borg_src/mt19937ar.c $(LIBS) $(JULIAFLAGS)

slurm: 
	$(MPICC) $(CFLAGS) -o main.exe main.c borg_src/borgms.c borg_src/mt19937ar.c $(LIBS) $(JULIAFLAGS_SLURM)
 
clean:
	rm main.exe