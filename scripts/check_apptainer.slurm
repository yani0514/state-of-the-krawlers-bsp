#!/bin/bash -l

#SBATCH --job-name=check-apptainer
#SBATCH --account=students
#SBATCH --partition=batch
#SBATCH --qos=low
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=2G
#SBATCH --time=00:10:00
#SBATCH --output=slurm-logs/%x-%j.out
#SBATCH --error=slurm-logs/%x-%j.err

set -Eeuo pipefail

module load tools/Apptainer/1.4.0

echo "Node: $(hostname)"
echo "Job:  $SLURM_JOB_ID"
command -v apptainer
apptainer --version

apptainer exec docker://alpine:latest \
  sh -c 'echo "Hello from Apptainer"; cat /etc/os-release | head'
