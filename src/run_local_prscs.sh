#!/bin/bash
set -e

# This script runs the full PRS-CS pipeline, assuming the GWAS file
# has already been formatted by 'reformat_gwas.sh'.

# --- Configuration ---
BASE_DIR="."
RESULTS_DIR="${BASE_DIR}/results_local"
TEST_DATA_DIR="${BASE_DIR}/test_data"

# This file MUST be created by 'reformat_gwas.sh' first.
# IMPORTANT: Replace 'username' with your actual username if it's different.
FORMATTED_GWAS_FILE="/home/username/Desktop/PRScs/final_gwas_for_prscs.txt"

LD_REF_DIR="${TEST_DATA_DIR}/ldblk_1kg_eur"
MAP_FILE="${TEST_DATA_DIR}/GlobalDiversityArray_PRS_PLINK_Forward_Strand_Format.map"
PED_FILE="${TEST_DATA_DIR}/GlobalDiversityArray_PRS_PLINK_Forward_Strand_Format.ped"

PLINK_BINARY_DIR="${RESULTS_DIR}/plink_binary"
PLINK_BINARY_PREFIX="${PLINK_BINARY_DIR}/gda_binary"
FREQ_FILE_PATH="${PLINK_BINARY_DIR}/gda_freqs.afreq"
PRSCS_OUT_PREFIX="${RESULTS_DIR}/prscs_out"
COMBINED_SCORE_FILE="${RESULTS_DIR}/gda_score_file.txt"
FINAL_PRS_PREFIX="${RESULTS_DIR}/gda_prs_final"

echo "--- Starting Final PRS-CS Workflow ---"

# 1. Prerequisite Check: Ensure the formatted GWAS file exists.
echo "--- Step 1: Checking for formatted GWAS file ---"
if [ ! -s "$FORMATTED_GWAS_FILE" ]; then
    echo "Error: Formatted GWAS file not found or is empty: ${FORMATTED_GWAS_FILE}"
    echo "Please run './reformat_gwas.sh' first to create it."
    exit 1
fi
echo "Formatted GWAS file found."
echo ""

# 2. Convert, Sort, and Filter Target Genotype Data
echo "--- Step 2: Preparing PLINK binary files ---"
mkdir -p "${PLINK_BINARY_DIR}"
TEMP_PLINK_PREFIX="${PLINK_BINARY_DIR}/temp_sorted"
plink2 --map "${MAP_FILE}" --ped "${PED_FILE}" --make-pgen --sort-vars --out "${TEMP_PLINK_PREFIX}"
plink2 --pfile "${TEMP_PLINK_PREFIX}" --chr 1-22 --make-bed --out "${PLINK_BINARY_PREFIX}"
echo "PLINK files created."
echo ""

# 3. Calculate Allele Frequencies
echo "--- Step 3: Calculating allele frequencies ---"
plink2 --bfile "${PLINK_BINARY_PREFIX}" --freq --out "${PLINK_BINARY_DIR}/gda_freqs"
echo "Allele frequencies calculated."
echo ""

# 4. Run PRS-cs
echo "--- Step 4: Running PRScs.py ---"
python3 PRScs.py \
    --ref_dir="${LD_REF_DIR}" \
    --bim_prefix="${PLINK_BINARY_PREFIX}" \
    --sst_file="${FORMATTED_GWAS_FILE}" \
    --n_gwas=706961 \
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