#!/bin/bash

# Script to calculate Polygenic Risk Scores using PLINK2

# --- Configuration: Directory Paths ---
# Assuming the script is run from the 'Linh PRS' directory
BASE_DIR="." # Current directory
INPUT_DATA_DIR="${BASE_DIR}/data/input"
CONVERTED_BINARY_DIR="${BASE_DIR}/data/converted_binary"
RESULTS_DIR="${BASE_DIR}/results"

# --- Configuration: File Names ---
#MAP_FILE_NAME="Forward_UNLV_GlobalDiversityArray_PRS_20231213.map"
#PED_FILE_NAME="Forward_UNLV_GlobalDiversityArray_PRS_20231213.ped"
MAP_FILE_NAME="Top_UNLV_GlobalDiversityArray_PRS_20231213.map"
PED_FILE_NAME="Top_UNLV_GlobalDiversityArray_PRS_20231213.ped"
BETA_CSV_FILE_NAME="betas.csv" # I believe this can be replaced with a GWAS data at a later time.

# Output file name prefixes (without directory paths)
PLINK_BINARY_NAME_PREFIX="unlv_gda_binary"
SCORE_FILE_NAME="my_scores.txt"
FREQ_FILE_NAME_PREFIX="${PLINK_BINARY_NAME_PREFIX}_freqs"
PRS_RESULTS_NAME_PREFIX="unlv_prs_results"

# --- Construct full paths for files ---
MAP_FILE="${INPUT_DATA_DIR}/${MAP_FILE_NAME}"
PED_FILE="${INPUT_DATA_DIR}/${PED_FILE_NAME}"
BETA_CSV_FILE="${INPUT_DATA_DIR}/${BETA_CSV_FILE_NAME}"

# PLINK2 binary files will be prefixed with the directory path
PLINK_BINARY_OUT_PREFIX="${CONVERTED_BINARY_DIR}/${PLINK_BINARY_NAME_PREFIX}"

# Score file will be placed in the converted_binary directory
SCORE_FILE_PATH="${CONVERTED_BINARY_DIR}/${SCORE_FILE_NAME}"

# Allele frequency files will be prefixed with the directory path
FREQ_FILE_OUT_PREFIX="${CONVERTED_BINARY_DIR}/${FREQ_FILE_NAME_PREFIX}"
FREQ_FILE_AFREQ_PATH="${FREQ_FILE_OUT_PREFIX}.afreq" # Full path to the .afreq file

# PRS results files will be prefixed with the directory path
PRS_RESULTS_OUT_PREFIX="${RESULTS_DIR}/${PRS_RESULTS_NAME_PREFIX}"
PRS_SSCORE_FILE_PATH="${PRS_RESULTS_OUT_PREFIX}.sscore" # Full path to the .sscore file

# --- Create output directories if they don't exist ---
mkdir -p "${CONVERTED_BINARY_DIR}"
mkdir -p "${RESULTS_DIR}"
echo "Ensured output directories exist:"
echo "  Converted binary data: ${CONVERTED_BINARY_DIR}"
echo "  Results: ${RESULTS_DIR}"
echo ""

# --- Step 1: Prepare the scoring file from betas.csv ---
echo "Step 1: Preparing scoring file (${SCORE_FILE_PATH}) from ${BETA_CSV_FILE}..."
if [ ! -f "${BETA_CSV_FILE}" ]; then
    echo "Error: Beta CSV file not found: ${BETA_CSV_FILE}"
    exit 1
fi
# We need rsid (col 1), effect_allele (col 4), and Beta (col 6) from betas.csv
# Assuming betas.csv has a header, we skip the first line (header) using tail -n +2
# awk extracts and prints the required columns, stripping leading/trailing whitespace.
tail -n +2 "${BETA_CSV_FILE}" | awk -F',' '{gsub(/^[ \t]+|[ \t]+$/, "", $1); gsub(/^[ \t]+|[ \t]+$/, "", $4); gsub(/^[ \t]+|[ \t]+$/, "", $6); print $1 "\t" $4 "\t" $6}' > "${SCORE_FILE_PATH}"

if [ ! -s "${SCORE_FILE_PATH}" ]; then
    echo "Error: Failed to create or scoring file is empty: ${SCORE_FILE_PATH}"
    echo "Please check ${BETA_CSV_FILE} and the awk command."
    exit 1
fi
echo "Scoring file ${SCORE_FILE_PATH} created successfully."
echo "Preview of ${SCORE_FILE_PATH} (first 5 lines):"
head -n 5 "${SCORE_FILE_PATH}"
echo ""

# --- Step 2: Convert .map and .ped files to PLINK2 binary format ---
echo "Step 2: Converting .map and .ped to PLINK2 binary format (output prefix: ${PLINK_BINARY_OUT_PREFIX}) and sorting variants..."
if [ ! -f "${MAP_FILE}" ] || [ ! -f "${PED_FILE}" ]; then
    echo "Error: MAP file (${MAP_FILE}) or PED file (${PED_FILE}) not found."
    exit 1
fi

plink2 \
    --map "${MAP_FILE}" \
    --ped "${PED_FILE}" \
    --make-pgen \
    --sort-vars \
    --out "${PLINK_BINARY_OUT_PREFIX}"

if [ ! -f "${PLINK_BINARY_OUT_PREFIX}.pgen" ] || [ ! -f "${PLINK_BINARY_OUT_PREFIX}.pvar" ] || [ ! -f "${PLINK_BINARY_OUT_PREFIX}.psam" ]; then
    echo "Error: Failed to create PLINK2 binary files."
    echo "Please check the plink2 command, its log file (${PLINK_BINARY_OUT_PREFIX}.log), and the input .map/.ped files."
    exit 1
fi
echo "PLINK2 binary files created successfully in ${CONVERTED_BINARY_DIR}."
echo ""

# --- Step 2.5: Calculate allele frequencies from the PLINK2 binary fileset ---
echo "Step 2.5: Calculating allele frequencies (output prefix: ${FREQ_FILE_OUT_PREFIX})..."
plink2 \
    --pfile "${PLINK_BINARY_OUT_PREFIX}" \
    --freq \
    --out "${FREQ_FILE_OUT_PREFIX}"

if [ ! -f "${FREQ_FILE_AFREQ_PATH}" ]; then
    echo "Error: Failed to calculate allele frequencies. The .afreq file was not created: ${FREQ_FILE_AFREQ_PATH}"
    echo "Please check the plink2 --freq command and its log file (${FREQ_FILE_OUT_PREFIX}.log)."
    exit 1
fi
echo "Allele frequencies calculated successfully: ${FREQ_FILE_AFREQ_PATH}"
echo ""

# --- Step 3: Calculate the Polygenic Risk Score ---
# Ensure each line ending with '\' has NO characters (especially spaces) after the '\'
echo "Step 3: Calculating Polygenic Risk Scores (output prefix: ${PRS_RESULTS_OUT_PREFIX})..."
plink2 \
    --pfile "${PLINK_BINARY_OUT_PREFIX}" \
    --read-freq "${FREQ_FILE_AFREQ_PATH}" \
    --score "${SCORE_FILE_PATH}" 1 2 3 cols=+scoresums \
    --out "${PRS_RESULTS_OUT_PREFIX}"

if [ ! -f "${PRS_SSCORE_FILE_PATH}" ]; then
    echo "Error: Failed to calculate PRS. The .sscore file was not created: ${PRS_SSCORE_FILE_PATH}"
    echo "Please check the plink2 --score command and its log file (${PRS_RESULTS_OUT_PREFIX}.log)."
    exit 1
fi

echo ""
echo "--- PRS Calculation Complete ---"
echo "Input genotype files: ${MAP_FILE}, ${PED_FILE}"
echo "Input beta summary statistics: ${BETA_CSV_FILE}"
echo ""
echo "Intermediate scoring file: ${SCORE_FILE_PATH}"
echo "PLINK2 binary files generated: ${PLINK_BINARY_OUT_PREFIX}.pgen, .pvar, .psam"
echo "Allele frequency file generated: ${FREQ_FILE_AFREQ_PATH}"
echo ""
echo "PRS results are in: ${PRS_SSCORE_FILE_PATH}"
echo "Log file for conversion step: ${PLINK_BINARY_OUT_PREFIX}.log"
echo "Log file for frequency calculation: ${FREQ_FILE_OUT_PREFIX}.log"
echo "Log file for the scoring step: ${PRS_RESULTS_OUT_PREFIX}.log"
echo ""
echo "You can view the top of the results file with: head ${PRS_SSCORE_FILE_PATH}"
echo "---------------------------------"

exit 0