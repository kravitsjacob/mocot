
#SBATCH --ntasks=144
#SBATCH --cpus-per-task=1
#SBATCH --switches=1
#SBATCH --constraint=ib
#SBATCH --output=output.txt
#SBATCH --error=error.txt
#SBATCH --job-name=gosox
#SBATCH --partition=amilan
#SBATCH --time=0-00:10:00
#SBATCH --mail-user=jakr3868@colorado.edu
#SBATCH --mail-type=ALL

# Setup
module purge
cd ..
. analysis/slurm_config.sh

# Run analysis
mpiexec -n 144 ./analysis/main.exe
