#!/bin/bash -l

#SBATCH --job-name=check-arachnarium-env
#SBATCH --account=students
#SBATCH --partition=batch
#SBATCH --qos=low
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=4G
#SBATCH --time=00:10:00
#SBATCH --output=slurm-logs/%x-%j.out
#SBATCH --error=slurm-logs/%x-%j.err

set -u

echo "=== Basic environment ==="
date
hostname
whoami
pwd
echo "SLURM_JOB_ID=$SLURM_JOB_ID"
echo "PATH=$PATH"

echo
echo "=== Commands ==="
for cmd in docker podman apptainer singularity module java mvn python3; do
    printf '%-12s: ' "$cmd"
    command -v "$cmd" || echo "not found"
done

echo
echo "=== Versions ==="
docker --version 2>&1 || true
docker compose version 2>&1 || true
podman --version 2>&1 || true
apptainer --version 2>&1 || true
singularity --version 2>&1 || true
java -version 2>&1 || true
python3 --version 2>&1 || true

echo
echo "=== Module initialization ==="
type module 2>&1 || true

if [[ -f /etc/profile.d/modules.sh ]]; then
    source /etc/profile.d/modules.sh
fi

if [[ -f /etc/profile.d/lmod.sh ]]; then
    source /etc/profile.d/lmod.sh
fi

type module 2>&1 || true

if type module >/dev/null 2>&1; then
    echo
    echo "=== Available container modules ==="
    module avail 2>&1 | grep -Ei 'apptainer|singularity|docker|podman|container' || true
fi

echo
echo "=== Project files ==="
ls -la "$HOME/Summer-BSP"
ls -la "$HOME/Summer-BSP/state-of-the-krawlers/scripts"

echo
echo "Diagnostic completed."
