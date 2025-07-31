#!/bin/bash
set -e

# This script runs the full PRS-CS pipeline.
# It assumes the GWAS file has already been formatted by 'reformat_gwas.sh'.
# It is designed to be run from the project's root directory.

# ==============================================================================
# --- Main Configuration ---
# ==============================================================================
# This is the sample size (N) of the GWAS study you are using.
# You MUST update this value if you change the GWAS summary statistics file.
# The value for the Chronic Periodontitis study (GCST90044102) is 456,285.
GWAS_SAMPLE_SIZE=456285
# ==============================================================================

# --- Path Configuration ---
# All paths are relative to the project root directory.
BASE_DIR="."
RESULTS_DIR="${BASE_DIR}/results"
INPUT_DATA_DIR="${BASE_DIR}/data/input"
LD_REF_DIR="${BASE_DIR}/data/linkage_disequilibrium_ref"
CONVERTED_BINARY_DIR="${BASE_DIR}/data/converted_binary"

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

# 1. Prerequisite Check: Ensure the formatted GWAS file exists.
echo "--- Step 1: Checking for formatted GWAS file ---"
if [ ! -s "$FORMATTED_GWAS_FILE" ]; then
    echo "Error: Formatted GWAS file not found or is empty: ${FORMATTED_GWAS_FILE}"
    echo "Please run './src/reformat_gwas.sh' first to create it."
    exit 1
fi
echo "Formatted GWAS file found."
echo ""

# 2. Convert, Sort, and Filter Target Genotype Data
echo "--- Step 2: Preparing PLINK binary files ---"
# Create directories if they don't exist
mkdir -p "${CONVERTED_BINARY_DIR}" "${RESULTS_DIR}"
TEMP_PLINK_PREFIX="${CONVERTED_BINARY_DIR}/temp_sorted"
plink2 --map "${MAP_FILE}" --ped "${PED_FILE}" --make-pgen --sort-vars --out "${TEMP_PLINK_PREFIX}"
plink2 --pfile "${TEMP_PLINK_PREFIX}" --chr 1-22 --make-bed --out "${PLINK_BINARY_PREFIX}"
echo "PLINK files created in ${CONVERTED_BINARY_DIR}"
echo ""

# 3. Calculate Allele Frequencies
echo "--- Step 3: Calculating allele frequencies ---"
plink2 --bfile "${PLINK_BINARY_PREFIX}" --freq --out "${CONVERTED_BINARY_DIR}/gda_freqs"
echo "Allele frequencies calculated."
echo ""

# 4. Run PRS-cs
echo "--- Step 4: Running PRScs.py ---"
# The --n_gwas parameter now uses the variable defined at the top of the script.
python3 "${BASE_DIR}/PRScs.py" \
    --ref_dir="${LD_REF_DIR}" \
    --bim_prefix="${PLINK_BINARY_PREFIX}" \
    --sst_file="${FORMATTED_GWAS_FILE}" \
    --n_gwas=${GWAS_SAMPLE_SIZE} \
    --out_dir="${PRSCS_OUT_PREFIX}"
echo "PRS-CS completed."
echo ""

# 5. Combine PRS-CS Output
echo "--- Step 5: Combining PRS-CS results ---"
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

# 6. Calculate Final PRS
echo "--- Step 6: Calculating final scores with PLINK2 ---"
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