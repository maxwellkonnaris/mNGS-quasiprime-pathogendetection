#!/bin/bash

#SBATCH --nodes=1
#SBATCH --ntasks=16 
#SBATCH --mem=150GB 
#SBATCH --time=48:00:00 
#SBATCH --account=open 
#SBATCH --output=run.out
#SBATCH --error=run.err
#SBATCH --export=ALL
#SBATCH --mail-type=FAIL,BEGIN,END
#SBATCH --mail-user=mak6930@psu.edu
#SBATCH --job-name=jellyfishing

############################################################################################################################################################### SET UP AND FILES ###################################################
##################################################################################################################

set -euo pipefail

# Specify main directory containing both input and output directories
cd "/storage/group/izg5139/default/maxwell/dissertation/metamak/" || { echo "Error: Unable to change directory: /storage/group/izg5139/default/maxwell/dissertation/metamak/" >> "$ERROR_LOG"; exit 1; }

# Specify the input directory containing subdirectories
INPUT_DIR="/storage/group/izg5139/default/maxwell/dissertation/metamak/datasets"

# Specify the output directory where Jellyfish results will be stored
OUTPUT_DIR="/storage/group/izg5139/default/maxwell/dissertation/metamak/kmercounts"

# Specify ERROR log file location
ERROR_LOG="error-log.txt"

# Validate error log
if [ ! -f "${ERROR_LOG}" ]; then
    touch "${ERROR_LOG}" || { echo "Error: Unable to create error log file: ${ERROR_LOG}" >&2; exit 1; }
fi

module load jellyfish
module load parallel

# Set the number of parallel processes (adjust as needed)
NUM_PROCESSES=16

# Validate input directory
if [ ! -d "${INPUT_DIR}" ]; then
    echo "Error: Input directory not found: ${INPUT_DIR}" >> "$ERROR_LOG"
    exit 1
fi

BASENAME=$(basename "${OUTPUT_DIR}")

# Check if the output directory exists
if [ ! -d "${OUTPUT_DIR}" ]; then
    mkdir -p "${OUTPUT_DIR}" || { echo "Error: Unable to create directory: ${OUTPUT_DIR}" >> "$ERROR_LOG"; exit 1; }
    echo "Created directory: ${OUTPUT_DIR}"
fi

echo " "
echo "Going Jellyfishing"

############################################################################################################################################################### JELLYFISHING mNGS ##################################################
##################################################################################################################

# Specify main directory containing both input and output directories
cd "${OUTPUT_DIR}" || { echo "Error: Unable to change directory: ${OUTPUT_DIR}" >> "$ERROR_LOG"; exit 1; }

# Function to process a subdirectory
process_subdirectory() {
    SUBDIR="$1"
    echo "Processing: ${SUBDIR}"

    # Check if the input directory exists
    if [ ! -d "${SUBDIR}" ]; then
        echo "Error: Input directory does not exist: ${SUBDIR}" >> "$ERROR_LOG"
        return 1
    else
        echo "PASS: Input directory exists: ${SUBDIR}"
    fi

    # specify output directory
    OUTPUT_DIR="/storage/group/izg5139/default/maxwell/dissertation/metamak/kmercounts"
    
    # Create corresponding output subdirectory
    BASENAME2=$(basename "${SUBDIR}")
    OUTPUT_SUBDIR="${OUTPUT_DIR}/${BASENAME2}"
    echo "Jellyfishing output location: ${OUTPUT_SUBDIR}"

#    if [ ! -d "${OUTPUT_SUBDIR}" ]; then
#        mkdir -p "${OUTPUT_SUBDIR}" || { echo "Error: Unable to create directory: ${OUTPUT_SUBDIR}" >> "$ERROR_LOG"; return 1; }
#        echo "Created directory: ${OUTPUT_SUBDIR}"
#    else
#        echo "PASS: Output directory exists: ${OUTPUT_SUBDIR}"
#    fi

    # Process each file in the subdirectory
    find "${SUBDIR}" -maxdepth 1 -type f -name '*.fastq.gz' | while read -r FILE; do
        if [ ! -e "${FILE}" ]; then
            echo "Error: File not found: ${FILE}" >> "$ERROR_LOG"
            continue
        else 
            BASENAME_FILE=$(basename "${FILE}" .fastq.gz)
            echo "Processing File: ${BASENAME_FILE}"
        fi

        # Check if dumps file exists for 16mer
        if [[ -f "${OUTPUT_SUBDIR}/${BASENAME_FILE}_16_dumps.txt.gz" || -f "${OUTPUT_SUBDIR}/${BASENAME_FILE}_16_dumps.txt" ]]; then
            echo "${BASENAME_FILE} Dumps file exists for 16mer, skipping..."
        else
            ### 16-mer
	    if [[ -f "${OUTPUT_SUBDIR}/${BASENAME_FILE}_16mers.jf" ]]; then
            	echo "Jellyfish ${BASENAME_FILE} count file exists, skipping..."
            else
		
    		echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> Jellyfish 16 COUNT ${BASENAME_FILE}"		    
		# Create temporary file
                TMP_FILE=$(mktemp)

                # zcat into temporary file
                zcat "${FILE}" > "${TMP_FILE}"
            	
		jellyfish count -m 16 -s 1000M -t 16 -o "${OUTPUT_SUBDIR}/${BASENAME_FILE}_16mers.jf" "${TMP_FILE}"
            fi

            # Dump 16mer
	    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> Jellyfish 16 DUMP ${BASENAME_FILE}"
            jellyfish dump -c -t "${OUTPUT_SUBDIR}/${BASENAME_FILE}_16mers.jf" > "${OUTPUT_SUBDIR}/${BASENAME_FILE}_16_dumps.txt"
            gzip "${OUTPUT_SUBDIR}/${BASENAME_FILE}_16_dumps.txt"

	    # Check if the operation was successful
            if [ $? -ne 0 ]; then
                echo "Error: K-mer counting failed for ${BASENAME_FILE}" >> "$ERROR_LOG"
                rm "${TMP_FILE}"
                rm "${OUTPUT_SUBDIR}/${BASENAME_FILE}_16mers.jf"
                continue
            fi

        fi

        # Check if dumps file exists for 17mer
        if [[ -f "${OUTPUT_SUBDIR}/${BASENAME_FILE}_17_dumps.txt.gz" || -f "${OUTPUT_SUBDIR}/${BASENAME_FILE}_17_dumps.txt" ]]; then
            echo "${BASENAME_FILE} Dumps file exists for 17mer, skipping..."
        else

            ### 17-mer
	    if [[ -f "${OUTPUT_SUBDIR}/${BASENAME_FILE}_17mers.jf" ]]; then
            	echo "Jellyfish ${BASENAME_FILE} count file exists, skipping..."
            else
                echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> Jellyfish 17 COUNT ${BASENAME_FILE}"
                # Create temporary file
                TMP_FILE=$(mktemp)

                # zcat into temporary file
                zcat "${FILE}" > "${TMP_FILE}"

		jellyfish count -m 17 -s 1000M -t 16 -o "${OUTPUT_SUBDIR}/${BASENAME_FILE}_17mers.jf" "${TMP_FILE}"
            fi

            # Dump 17mer
	    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> Jellyfish 17 DUMP ${BASENAME_FILE}"
            jellyfish dump -c -t "${OUTPUT_SUBDIR}/${BASENAME_FILE}_17mers.jf" > "${OUTPUT_SUBDIR}/${BASENAME_FILE}_17_dumps.txt"
            gzip "${OUTPUT_SUBDIR}/${BASENAME_FILE}_17_dumps.txt"

            # Check if the operation was successful
            if [ $? -ne 0 ]; then
                echo "Error: K-mer counting failed for ${BASENAME_FILE}" >> "$ERROR_LOG"
                rm "${TMP_FILE}"
        	rm "${OUTPUT_SUBDIR}/${BASENAME_FILE}_17mers.jf"
		continue
            fi

        fi

        echo "${BASENAME_FILE} K-mer counting completed!"
    done

    if [ -s "$ERROR_LOG" ]; then
        echo "----------Errors detected. Check ${ERROR_LOG} for details.----------"
        exit 1
    else
        echo "----------${BASENAME2} K-mer counting completed!----------"
    fi
}

############################################################################################################################################################### END JELLYFISH  #####################################################
##################################################################################################################

export -f process_subdirectory

# Find all subdirectories and distribute them among parallel processes
find "${INPUT_DIR}" -mindepth 1 -maxdepth 1 -type d | \
    parallel -j "${NUM_PROCESSES}" process_subdirectory

echo "--------------------------------------------------Completed run time for jellyfishing mNGS------------------------------------------------------------"
