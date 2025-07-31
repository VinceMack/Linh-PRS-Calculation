#!/bin/bash
set -e

# This script runs the full PRS-CS pipeline.
# It automatically determines the project's root directory and the LD reference path.

# ==============================================================================
# --- Main Configuration ---
# ==============================================================================
GWAS_SAMPLE_SIZE=456285
# ==============================================================================

# --- Dynamic Path Configuration ---
# Get the directory where this script is located.
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
# The project root is one level up from the 'src' directory.
ROOT_DIR=$(dirname "$SCRIPT_DIR")

# --- Path Configuration ---
RESULTS_DIR="${ROOT_DIR}/results"
INPUT_DATA_DIR="${ROOT_DIR}/data/input"
LD_PARENT_DIR="${ROOT_DIR}/data/linkage_disequilibrium_ref"
CONVERTED_BINARY_DIR="${ROOT_DIR}/data/converted_binary"
# Path to the directory containing the PRScs.py script
PRSCS_PROGRAM_DIR="${ROOT_DIR}/PRScs"

# Input files
FORMATTED_GWAS_FILE="${INPUT_DATA_DIR}/formatted_gwas.txt"
MAP_FILE="${INPUT_DATA_DIR}/GlobalDiversityArray_PRS_PLINK_Forward_Strand_Format.map"
PED_FILE="${INPUT_DATA_DIR}/GlobalDiversityArray_PRS_PLINK_Forward_Strand_Format.ped"

# Output file prefixes and paths
PLINK_BINARY_PREFIX="${CONVERTED_BINARY_DIR}/gda_binary"
FREQ_FILE_PATH="${CONVERTED_BINARY_DIR}/gda_freqs.afreq"
PRSCS_OUT_PREFIX="${RESULTS_DIR}/prscs_out"
COMBINED_SCORE_FILE="${RESULTS_DIR}/gda_score_file.txt"
FINAL_PRS_PREFIX="${RESULTS_DIR}/gda_prs_final"

echo "--- Starting Final PRS-CS Workflow ---"

# --- Dynamic LD Reference Path Detection ---
echo "--- Step 1: Detecting LD Reference directory ---"
# Count the number of subdirectories inside the LD parent directory.
NUM_LD_DIRS=$(find "${LD_PARENT_DIR}" -mindepth 1 -maxdepth 1 -type d | wc -l)

if [ "$NUM_LD_DIRS" -eq 0 ]; then
    echo "Error: No LD Reference directory found inside ${LD_PARENT_DIR}"
    echo "Please place your LD reference panel (e.g., 'ldblk_1kg_eur') inside that folder."
    exit 1
elif [ "$NUM_LD_DIRS" -gt 1 ]; then
    echo "Error: Multiple directories found inside ${LD_PARENT_DIR}"
    echo "Please ensure there is only ONE subdirectory containing the LD reference panel."
    exit 1
else
    # If exactly one directory is found, get its full path.
    LD_REF_DIR_RAW=$(ls -d ${LD_PARENT_DIR}/*/)
    LD_REF_DIR=${LD_REF_DIR_RAW%/} # Remove trailing slash
    echo "Found LD Reference: ${LD_REF_DIR}"
fi
echo ""

# --- Prerequisite Check ---
echo "--- Step 2: Checking for formatted GWAS file ---"
if [ ! -s "$FORMATTED_GWAS_FILE" ]; then
    echo "Error: Formatted GWAS file not found or is empty: ${FORMATTED_GWAS_FILE}"
    echo "Please run './src/reformat_gwas.sh' first to create it."
    exit 1
fi
echo "Formatted GWAS file found."
echo ""

# --- Prepare PLINK binary files ---
echo "--- Step 3: Preparing PLINK binary files ---"
mkdir -p "${CONVERTED_BINARY_DIR}" "${RESULTS_DIR}"
TEMP_PLINK_PREFIX="${CONVERTED_BINARY_DIR}/temp_sorted"
plink2 --map "${MAP_FILE}" --ped "${PED_FILE}" --make-pgen --sort-vars --out "${TEMP_PLINK_PREFIX}"
plink2 --pfile "${TEMP_PLINK_PREFIX}" --chr 1-22 --make-bed --out "${PLINK_BINARY_PREFIX}"
echo "PLINK files created in ${CONVERTED_BINARY_DIR}"
echo ""

# --- Calculate Allele Frequencies ---
echo "--- Step 4: Calculating allele frequencies ---"
plink2 --bfile "${PLINK_BINARY_PREFIX}" --freq --out "${CONVERTED_BINARY_DIR}/gda_freqs"
echo "Allele frequencies calculated."
echo ""

# --- Run PRS-cs ---
echo "--- Step 5: Running PRScs.py ---"
# CORRECTED PATH: This now points to the PRScs.py script inside the 'PRScs' subdirectory.
python3 "${PRSCS_PROGRAM_DIR}/PRScs.py" \
    --ref_dir="${LD_REF_DIR}" \
    --bim_prefix="${PLINK_BINARY_PREFIX}" \
    --sst_file="${FORMATTED_GWAS_FILE}" \
    --n_gwas=${GWAS_SAMPLE_SIZE} \
    --out_dir="${PRSCS_OUT_PREFIX}"
echo "PRS-CS completed."
echo ""

# --- Combine PRS-CS Output ---
echo "--- Step 6: Combining PRS-CS results ---"
HEADER_WRITTEN=false
for i in {1..22}; do
    CHUNK_FILE="${PRSCS_OUT_PREFIX}_pst_eff_a1_b0.5_phiauto_chr${i}.txt"
    if [ -f "$CHUNK_FILE" ]; then
        if [ "$HEADER_WRITTEN" = false ]; then head -n 1 "$CHUNK_FILE" > "${COMBINED_SCORE_FILE}"; HEADER_WRITTEN=true; fi
        tail -n +2 "$CHUNK_FILE" >> "${COMBINED_SCORE_FILE}"
    fi
done
echo "Scoring file created."
echo ""

# --- Calculate Final PRS ---
echo "--- Step 7: Calculating final scores with PLINK2 ---"
plink2 \
    --bfile "${PLINK_BINARY_PREFIX}" \
    --read-freq "${FREQ_FILE_PATH}" \
    --score "${COMBINED_SCORE_FILE}" 2 4 6 header cols=+scoresums \
    --out "${FINAL_PRS_PREFIX}"

echo ""
echo "--- PRS Calculation Complete ---"
echo "Final Polygenic Risk Scores are located in: ${FINAL_PRS_PREFIX}.sscore"
echo "You can view the results with: head ${FINAL_PRS_PREFIX}.sscore"
echo "---------------------------------"

exit 0