#!/bin/bash

version="1.0.0"

# Display usage
function usage {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -v, --verbose           Verbosity level from 1 (low) to 3 (high)"
    # echo "  -c, --chromosomes  Fasta file or chromosome sizes"
    echo "  -g, --genome            Human genome (possible choices: hg19, hg38, T2T)"
    echo "  --vcf                   Multi-sample VCF file"
    echo "  -p, --pedfile           family info 1-line: "
    echo "  -n, --naming_chr        specify a name to use for chromosome naming in the plot (e.g. 'chr') [ default='' ]"
    echo "  -r, --readdepth         minimum read depth to consider a position [ default=''8' ]"
    echo "  -o, --output            filename of the .png output file [ default='plot.png' ]"
    echo "  -k, --keepcreatedfiles  keep the existing files created with UPDgraph : yes/no [ default='no' ]"
    echo "  -t, --threads           number of threads to use with bcftools [ default='1' ]"
    exit 1
}

# Variables to store options and default options
verbose="1"
chromosomes=""
genome=""
vcf=""
output="plot.png"
pedfile=""
naming_chr=""
readdepth="8"
keepcreatedfiles="no"
threads="1"

chrom_list_noY="chr1,chr2,chr3,chr4,chr5,chr6,chr7,chr8,chr9,chr10,chr11,chr12,chr13,chr14,chr15,chr16,chr17,chr18,chr19,chr20,chr21,chr22,chrX,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,X"
chrom_list_Y="Y,chrY"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -v|--verbose)
            verbose="$2"
            if [[ "$verbose" != "1" && "$verbose" != "2" && "$verbose" != "3" ]]; then
                echo "Error: -v/--verbose must be 1, 2, or 3."
                usage
            fi
            shift 2
            ;;
        -c|--chromosomes)
            chromosomes="$2"
            shift 2
            ;;
        -g|--genome)
            genome="$2"
            if [[ -n "$genome" && "$genome" != "hg19" && "$genome" != "hg38" && "$genome" != "T2T" ]]; then
                echo "Error: -g/--genome must be hg19, hg38, or T2T."
                usage
            fi
            shift 2
            ;;
        --vcf)
            vcf="$2"
            shift 2
            ;;
        -o|--output)
            output="$2"
            shift 2
            ;;
        -p|--pedfile)
            pedfile="$2"
            shift 2
            ;;
        -n|--naming_chr)
            naming_chr="$2"
            shift 2
            ;;
        -r|--readdepth)
            readdepth="$2"
            shift 2
            if ! [[ "$readdepth" =~ ^[0-9]+$ ]]; then
                echo "Error: -r/--readdepth must be an integer."
                exit 1
            fi
            ;;
        -k|--keepcreatedfiles)
            keepcreatedfiles="$2"
            if [[ -n "$keepcreatedfiles" && "$keepcreatedfiles" != "no" && "$keepcreatedfiles" != "yes"  ]]; then
                echo "Error: -k/--keepcreatedfiles must be yes or no."
                usage
            fi
            shift 2
            ;;
        -t|--threads)
            threads="$2"
            if ! [[ "$threads" =~ ^[0-9]+$ ]]; then
                echo "Error: -t/--threads must be an integer."
                exit 1
            fi
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Check required options
# Check for mutually exclusive options $genome and $chromosomes
if [[ -n "$genome" && -n "$chromosomes" ]]; then
    echo "Error: The -g/--genome and -c/--chromosomes options are mutually exclusive."
    usage
elif [[ -z "$genome" && -z "$chromosomes" ]]; then
    echo "Error: One of the options -g/--genome or -c/--chromosomes is required."
    usage
fi



# Display of parsed options
echo -e "\n###############################"
echo -e "#######>   UDPgraph   <########"
echo -e "###############################\n"
echo "Version:              $version"
echo ""
echo "Verbosity level:      $verbose"
if [[ -n "$chromosomes" ]]; then
echo "Chromosomes:          $chromosomes"
fi
if [[ -n "$genome" ]]; then
echo "Genome:               $genome"
fi
echo "VCF file:             $vcf"
echo "pedfile:              $pedfile"
echo "naming_chr:           $naming_chr"
echo "read depth:           $readdepth"
echo "keep created files:   $keepcreatedfiles"
echo "threads:              $threads"
echo -e "###############################\n"

########################################################################
###                  Fasta file or chromosome sizes                  ###
########################################################################
# chrom_list_noY
# $chrom_list_Y

########################################################################
###                    Extract trio info from ped                    ###
########################################################################
echo ">> Extract trio info from ped "

# Check if the file exists
if [ -f $pedfile ]; then
    # Read the line from the file
    line=$(cat "$pedfile")

    # Count the number of elements
    num_elements=$(echo $line | awk '{print NF}')

    # Check that there are exactly 6 elements
    if [ "$num_elements" -eq 6 ]; then
        read -r family proband father mother sexproband diseasestatut <<< "$line"
        echo "family: $family"
        echo "proband: $proband"
        echo "father: $father "
        echo "mother: $mother"
        echo "sex proband: $sexproband"
        echo "disease statut: $diseasestatut"
    else
        echo "Error: The line does not contain exactly 6 elements."
    fi
else
    echo "Error: The ped file does not exist."
fi


########################################################################
###                 Index vcf/bcf file if not present                ###
########################################################################
echo ">> Index vcf/bcf file if not present"

# Determine the index file name based on the file extension
if [[ "$vcf" == *.vcf ]]; then
    inputfile="${vcf}.gz"
    bgzip -c "$vcf" > "$inputfile"
    index_file="${vcf}.gz.csi"
elif [[ "$vcf" == *.vcf.gz ]]; then
    inputfile="$vcf"
    index_file="${vcf}.csi"
elif [[ "$vcf" == *.bcf ]]; then
    inputfile="$vcf"
    index_file="${vcf}.csi"
else
    echo "Error: Unsupported file format. Please provide a VCF or BCF file."
    exit 1
fi

# Remove previous file if necessary
if [ -f "$index_file" ] && [ "$keepcreatedfiles" = "no" ]; then
    rm "$index_file"
    echo "Index file removed."
else
    echo "Index file already exists: $index_file"
fi

if [ ! -f "$index_file" ]; then
    bcftools index --threads "$threads" "$inputfile"
    echo "Index created: $index_file"
fi

########################################################################
###                Extract trio samples from bcf/vcf                 ###
########################################################################
# extract the trio samples from a multi-sample vcf and reorder the vcf if required
echo ">> Extract trio samples from bcf/vcf"

# output file name
trio_vcf_file=$family'.'$proband'.bcf'

# Get the list of samples in the VCF/BCF file
vcf_samples=$(bcftools query -l "$inputfile")

# Check if each sample exists in the VCF/BCF file
found_all_samples=""
for sample in $proband $father $mother; do
    if echo "$vcf_samples" | grep -q "^$sample$"; then
        echo "Sample $sample exists in the file."
    else
        echo "Sample $sample does not exist in the file."
        found_all_samples="no"
    fi
done

if [[ $found_all_samples != "no" ]]; then
  if [ -f "$trio_vcf_file" ] && [ "$keepcreatedfiles" = "no" ]; then
      rm "$trio_vcf_file"
      echo "'Trio vcf file' is removed."
  fi
  if [ ! -f "$trio_vcf_file" ]; then
    bcftools view --threads "$threads" -Ob -s "$proband","$father","$mother" -r "$chrom_list_noY","$chrom_list_Y" "$inputfile" > "$trio_vcf_file"
  fi
else
  echo "Not all samples are found in the vcf file"
  exit 1
fi


########################################################################
###                        Index trio bcf file                       ###
########################################################################
echo ">> Index trio bcf file"

# Remove previous file if necessary
if [ -f "${trio_vcf_file}.csi" ] && [ "$keepcreatedfiles" = "no" ]; then
  rm "${trio_vcf_file}.csi"
  echo "'Index trio bcf file' is removed."
fi
if [ ! -f "${trio_vcf_file}.csi" ]; then
  bcftools index --threads "$threads" "$trio_vcf_file"
fi

########################################################################
###          Analyse trio vcf and report variants of interest        ###
########################################################################
echo ">> Analyse trio vcf and report variants of interest"

variant_heredity_file="${family}.${proband}.DP${readdepth}.heredity_type.txt"

# erase file content if existing
truncate -s 0 "$variant_heredity_file"

# Variants inherited only from Father
# 1/1 1/1 0/0
# 1/1 0/1 0/0
# 0/0 0/1 1/1
# 0/0 0/0 1/1
bcftools view --threads "$threads" -r $chrom_list_noY -Ou "$trio_vcf_file" | bcftools view --threads "$threads" -Ou -i "FORMAT/DP[0] > $readdepth && FORMAT/DP[1] > $readdepth && FORMAT/DP[2] > $readdepth" | bcftools view --threads "$threads" -Ou -i '(FORMAT/GT[0] == "1/1" && FORMAT/GT[1] == "1/1" && FORMAT/GT[2] == "0/0") || (FORMAT/GT[0] == "1/1" && FORMAT/GT[1] == "0/1" && FORMAT/GT[2] == "0/0") || (FORMAT/GT[0] == "0/0" && FORMAT/GT[1] == "0/1" && FORMAT/GT[2] == "1/1") || (FORMAT/GT[0] == "0/0" && FORMAT/GT[1] == "0/0" && FORMAT/GT[2] == "1/1") ' | bcftools query -f "%CHROM\t%POS\tFF\n" | sed 's/^chr//' >> $variant_heredity_file

# Variants inherited only from Mother
# 1/1 0/0 1/1
# 1/1 0/0 0/1
# 0/0 1/1 0/1
# 0/0 1/1 0/0
bcftools view --threads "$threads" -r $chrom_list_noY -Ou "$trio_vcf_file" | bcftools view --threads "$threads" -Ou -i "FORMAT/DP[0] > $readdepth && FORMAT/DP[1] > $readdepth && FORMAT/DP[2] > $readdepth" | bcftools view --threads "$threads" -Ou -i '(FORMAT/GT[0] == "1/1" && FORMAT/GT[1] == "0/0" && FORMAT/GT[2] == "1/1") || (FORMAT/GT[0] == "1/1" && FORMAT/GT[1] == "0/0" && FORMAT/GT[2] == "0/1") || (FORMAT/GT[0] == "0/0" && FORMAT/GT[1] == "1/1" && FORMAT/GT[2] == "0/1") || (FORMAT/GT[0] == "0/0" && FORMAT/GT[1] == "1/1" && FORMAT/GT[2] == "0/0")' | bcftools query -f "%CHROM\t%POS\tFM\n" | sed 's/^chr//' >> "$variant_heredity_file"

# From both parents
# 0/1 1/1 0/0
# 0/1 0/0 1/1
bcftools view --threads "$threads" -r $chrom_list_noY -Ou "$trio_vcf_file" | bcftools view --threads "$threads" -Ou -i "FORMAT/DP[0] > $readdepth && FORMAT/DP[1] > $readdepth && FORMAT/DP[2] > $readdepth" | bcftools view --threads "$threads" -Ou -i '(FORMAT/GT[0] == "0/1" && FORMAT/GT[1] == "1/1" && FORMAT/GT[2] == "0/0") || (FORMAT/GT[0] == "0/1" && FORMAT/GT[1] == "0/0" && FORMAT/GT[2] == "1/1")' | bcftools query -f "%CHROM\t%POS\tBP\n" | sed 's/^chr//' >> "$variant_heredity_file"

# For chrY
# 1/1 1/1 -/-
if [[ $chrom_list_Y != "" ]]; then
    bcftools view --threads "$threads" -r $chrom_list_Y -Ou "$trio_vcf_file" | bcftools view --threads "$threads" -Ou -i "FORMAT/DP[0] > $readdepth && FORMAT/DP[1] > $readdepth && FORMAT/DP[2] < $((readdepth/2))" | bcftools view --threads "$threads" -Ou -i '(FORMAT/GT[0] == "1/1" && FORMAT/GT[1] == "1/1" && FORMAT/GT[2] != "0/1") || (FORMAT/GT[0] == "1/1" && FORMAT/GT[1] == "1/1" && FORMAT/GT[2] != "1/1")' | bcftools query -f "%CHROM\t%POS\tFF\n" | sed 's/^chr//' >> "$variant_heredity_file"
fi

########################################################################
###                       Get vcf for proband                        ###
########################################################################
echo ">> Get vcf for proband"

if [ -f "${proband}.proband.vcf" ] && [ "$keepcreatedfiles" = "no" ]; then
  rm "${proband}.proband.vcf"
  echo "'proband vcf file' is removed."
fi

if [ ! -f "${proband}.proband.vcf" ]; then
  bcftools view --threads "$threads" -Ov -s "$proband" -r "$chrom_list_noY","$chrom_list_Y" "$inputfile" > "${proband}.proband.vcf"
fi

########################################################################
###                           Run Automap                            ###
########################################################################
echo ">> Run Automap"

AUTOMAP_HOME="/opt/AutoMap/"

# Remove previous ROD dir if necessary
if [ -r "${proband}.ROH" ] && [ "$keepcreatedfiles" = "no" ]; then
  rm -r "${proband}.ROH"
  echo -e "Directory ${proband}.ROH is removed."
fi

if [ ! -f "${proband}.ROH/${proband}.ROH.HomRegions.tsv" ]; then
  if [[ -n "$genome" && ("$genome" == "hg19" || "$genome" == "hg38") ]]; then
      roh_file="${proband}.ROH/${proband}.ROH.HomRegions.tsv"
      bash $AUTOMAP_HOME/AutoMap_v1.3.1.sh --minsize 3 --vcf "${proband}.proband.vcf" --id "${proband}.ROH" --out "$PWD" --genome "$genome" --chrX || roh_file=""
  else
      roh_file=""
  fi
else
  roh_file=""
fi

########################################################################
###                          Make the plot                           ###
########################################################################
echo ">> Make the plot"
UPDgraph_py_HOME="."
# UPDgraph_py_HOME=/opt/UPDgraph/

python $UPDgraph_py_HOME/UPDgraph.py --file "$variant_heredity_file" --roh "$roh_file" -n "$naming_chr" -g "$genome" -o "$output"

########################################################################
###                            Terminate                             ###
########################################################################

echo "-- Processing complete --"
