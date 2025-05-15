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
#SBATCH --job-name=mNGSdatadownload

############################################################################################################################################################### SET UP AND FILES ###################################################
##################################################################################################################

# Check if SRA toolkit is installed
if command -v fastq-dump &>/dev/null; then
    echo "SRA toolkit is already installed."
else
    echo "SRA toolkit is not installed. Installing..."

    # Detect system type
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Install for Linux
        wget --output-document sratoolkit.tar.gz https://ftp-trace.ncbi.nlm.nih.gov/sra/sdk/current/sratoolkit.current-ubuntu64.tar.gz
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # Install for Mac
        wget --output-document sratoolkit.tar.gz https://ftp-trace.ncbi.nlm.nih.gov/sra/sdk/current/sratoolkit.current-mac64.tar.gz
    elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" || "$OSTYPE" == "cygwin" ]]; then
        # Install for Windows
        wget --output-document sratoolkit.zip https://ftp-trace.ncbi.nlm.nih.gov/sra/sdk/current/sratoolkit.current-win64.zip
    else
        # Unsupported system
        echo "Unsupported operating system. Please install SRA toolkit manually: https://github.com/ncbi/sra-tools/wiki/02.-Installing-SRA-Toolkit"
        exit 1
    fi

    tar -vxzf sratoolkit.tar.gz
    export PATH=$PATH:$PWD/$(tar -tf sratoolkit.tar.gz | head -n 1 | cut -f 1 -d '/')/bin
fi

# Check if Entrez Direct tools are installed
if command -v esearch &>/dev/null && command -v efetch &>/dev/null; then
    echo "Entrez Direct tools are already installed."
else
    echo "Entrez Direct tools are not installed. Installing..."

    # Prompt the user to choose between activating an existing environment or creating a new one
    read -p "Do you want to activate an existing environment (A) or create a new one (C)? " choice

    if [ "$choice" == "A" ] || [ "$choice" == "a" ]; then
      # List available conda environments
      echo "Available Conda Environments:"
      conda info --envs

      # Prompt the user to enter the environment name
      read -p "Enter the conda environment name to activate: " env_name

      # Activate the specified conda environment
      conda activate $env_name

      # Optional: Verify the activation
      echo "Activated Conda Environment: $env_name"

    elif [ "$choice" == "C" ] || [ "$choice" == "c" ]; then
      # Prompt the user to enter the name for the new conda environment
      read -p "Enter a name for the new conda environment: " new_env_name

      # Prompt the user to enter the Python version for the new environment
      read -p "Enter the Python version for the new environment (e.g., 3.8): " python_version

      # Create a new conda environment
      conda create -n $new_env_name python=$python_version

      # Activate the newly created conda environment
      conda activate $new_env_name

      # Optional: Verify the activation
      echo "Activated New Conda Environment: $new_env_name"

    else
      echo "Invalid choice. Please enter 'A' to activate an existing environment or 'C' to create a new one."
    fi
 
 
    conda install -c bioconda entrez-direct
    sh -c "$(curl -fsSL ftp://ftp.ncbi.nlm.nih.gov/entrez/entrezdirect/install-edirect.sh)"
    export PATH=${HOME}/edirect:${PATH}
     

    # Install Entrez Direct tools
    #if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Install for Linux
    #    wget --output-document edirect.zip ftp://ftp.ncbi.nlm.nih.gov/entrez/entrezdirect/edirect.zip
    #    unzip edirect.zip
    #    export PATH=$PATH:$PWD/edirect
    #elif [[ "$OSTYPE" == "darwin"* ]]; then
        # Install for Mac
    #    /bin/bash -c "$(curl -fsSL ftp://ftp.ncbi.nlm.nih.gov/entrez/entrezdirect/install-edirect.sh)"
    #    export PATH=$PATH:$HOME/edirect
    #elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" || "$OSTYPE" == "cygwin" ]]; then
        # Install for Windows
    #    echo "Please manually install Entrez Direct tools on Windows: https://www.ncbi.nlm.nih.gov/books/NBK179288/"
    #    exit 1
    #else
        # Unsupported system
    #    echo "Unsupported operating system. Please install Entrez Direct tools manually: https://www.ncbi.nlm.nih.gov/books/NBK179288/"
    #    exit 1
    #fi
fi

# PRJNA accession numbers to process
PRJNA_LIST=("PRJNA854064" "PRJNA516582" "PRJNA504776" "PRJNA665328" "PRJNA665350" "PRJNA788644" "PRJNA786578" "PRJNA518922" "PRJEB14038" "PRJNA560212" "PRJNA970731")
BIOPROJECT=("PRJCA008034" "PRJCA008503")

# Create directory for metagenomics study
mkdir -p metamak/datasets
cd metamak/datasets

# Function to download data based on SRA accession
download_SRR() {
    accession=$1
    echo "Downloading data for $accession"
    # Retrieve SRX numbers
    esearch -db sra -query "${accession}" | efetch -format runinfo | cut -d ',' -f 1 | grep SRR | xargs -I{} fastq-dump --split-files --gzip {}
}

# Function to download data based on SRA accession
download_ERR() {
    accession=$1
    echo "Downloading data for $accession"
    # Retrieve ERR numbers
    esearch -db sra -query "${accession}" | efetch -format runinfo | cut -d ',' -f 1 | grep ERR | xargs -I{} fastq-dump --split-files --gzip {}
}

# Download data for each project in parallel
download_project() {
    PRJNA=$1

    # Check if the directory already exists
    if [ -d "$PRJNA" ]; then
        echo "Directory '$PRJNA' already exists. Skipping download."
    elif [[ "$PRJNA" == PRJE* ]]; then
        # If $PRJNA starts with PRJE, do the following
        mkdir $PRJNA
        cd $PRJNA
        download_ERR $PRJNA
        cd ..
    else
        # If $PRJNA starts with PRJN or any other prefix, do the following
        mkdir $PRJNA
        cd $PRJNA
        download_SRR $PRJNA
        cd ..
    fi
}

export -f download_ERR
export -f download_SRR
export -f download_project

module load parallel

# Use parallel to download projects in parallel
parallel download_project ::: "${PRJNA_LIST[@]}"


# Download data for each project
##PRJNA854064 #Clinical evaluation of mNGS in unbiased pathogens diagnosis of UTIs, https://doi.org/10.1186/s12967-023-04562-0
##PRJCA008034 #Metagenomic Next-Generation Sequencing for the Diagnosis of Neonatal Infectious Diseases, 10.1128/spectrum.01195-22
##PRJCA008503 #Metagenomic Next-Generation Sequencing for the Diagnosis of Neonatal Infectious Diseases, 10.1128/spectrum.01195-22
##PRJNA516582 #Unbiased Metagenomic Sequencing for Pediatric Meningitis in Bangladesh Reveals Neuroinvasive Chikungunya Virus Outbreak and Other Unrealized Pathogens, 10.1128/mBio.02877-19 (No human reads)
##PRJNA504776 #Genomic and serologic characterization of enterovirus A71 brainstem encephalitis, 10.1212/NXI.0000000000000703
## https://pubmed.ncbi.nlm.nih.gov/34104666/
## https://www.ncbi.nlm.nih.gov/pmc/articles/PMC6549306/
##PRJNA66268 #Combining Metagenomic Sequencing With Whole Exome Sequencing to Optimize Clinical Strategies in Neonates With a Suspected Central Nervous System Infection, 10.3389/fcimb.2021.671109
##PRJNA665328 #Background Filtering of Clinical Metagenomic Sequencing with a Library Concentration-Normalized Model, 10.1128/spectrum.01779-22
##PRJNA665350 #Background Filtering of Clinical Metagenomic Sequencing with a Library Concentration-Normalized Model, 10.1128/spectrum.01779-22
##PRJNA788644 #Background Filtering of Clinical Metagenomic Sequencing with a Library Concentration-Normalized Model, 10.1128/spectrum.01779-22
##PRJNA786578 #Clinical Metagenomics Is Increasingly Accurate and Affordable to Detect Enteric Bacterial Pathogens in Stool, 10.3390/microorganisms10020441
##PRJNA518922 #Application of metagenomic shotgun sequencing to detect vector-borne pathogens in clinical blood samples, https://doi.org/10.1371/journal.pone.0222915
##PRJEB14038 #Evaluating the Potential of using Next-Generation Sequencing for Direct Clinical Diagnostics of Faecal Samples from Patients with Diarrhoea, 10.1007/s10096-017-2947-2
##PRJNA560212 #Performance of Five Metagenomic Classifiers for Virus Pathogen Detection Using Respiratory Samples from a Clinical Cohort, 10.3390/pathogens11030340
## https://www.frontiersin.org/articles/10.3389/fcimb.2022.957073/full#h7
##PRJNA970731 #https://www.nature.com/articles/s41597-023-02877-7, NIST Generated Gut Microbiome Mock Community
