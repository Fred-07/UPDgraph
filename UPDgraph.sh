#!/bin/bash

version="1.0.0"

# Display usage
function usage {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -v, --verbose            Verbosity level from 1 (low) to 3 (high)"
    # echo "  -c, --chromosomes  Fasta file or chromosome sizes"
    echo "  -g, --genome             Human genome (possible choices: hg19, hg38, T2T)"
    echo "  --vcf                    Multi-sample VCF file"
    echo "  -p, --pedfile            family info 1-line: "
    echo "  -n, --naming_chr         specify a name to use for chromosome naming in the plot (e.g. 'chr') [ default='' ]"
    echo "  -r, --readdepth          minimum read depth to consider a position [ default=''8' ]"
    echo "  -o, --output             filename of the .png output file [ default='plot.png' ]"
    echo "  -k, --overwritefiles     overwrite the existing files created previously with UPDgraph : yes/no [ default='yes' ]"
    echo "  -m, --keeptemporaryfiles keep temporary files created with UPDgraph : yes/no [ default='yes' ]"
    echo "  -t, --threads            number of threads to use with bcftools [ default='1' ]"
    echo "  -u, --UPDgraph_py_HOME   specify the path for UPDgraph.py. Default option uses UPDgraph.py from container [ default='/opt/UPDgraph/' ]"
    echo "  -a, --AUTOMAP_HOME       specify the path for automap_vx.x.x.sh. Default option uses automap_vx.x.x.sh from container [ default='/opt/AutoMap/' ]"
    echo "  -y, --show_chrY          plot the chromosome Y : yes/no [ default='yes' ]"

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
overwritefiles="yes"
keeptemporaryfiles="yes"
threads="1"
UPDgraph_py_HOME='/opt/UPDgraph/'
AUTOMAP_HOME="/opt/AutoMap/"

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
        -k|--overwritefiles)
            overwritefiles="$2"
            if [[ -n "$overwritefiles" && "$overwritefiles" != "no" && "$overwritefiles" != "yes"  ]]; then
                echo "Error: -k/--overwritefiles must be yes or no."
                usage
            fi
            shift 2
            ;;
        -m|--keeptemporaryfiles)
            keeptemporaryfiles="$2"
            if [[ -n "$keeptemporaryfiles" && "$keeptemporaryfiles" != "no" && "$keeptemporaryfiles" != "yes"  ]]; then
                echo "Error: -m/--keeptemporaryfiles must be yes or no."
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
        -u|--UPDgraph_py_HOME)
            UPDgraph_py_HOME="$2"
            shift 2
            ;;
        -a|--AUTOMAP_HOME)
            AUTOMAP_HOME="$2"
            shift 2
            ;;
        -y|--show_chrY)
            show_chrY="$2"
            if [[ -n "$show_chrY" && "$show_chrY" != "no" && "$show_chrY" != "yes"  ]]; then
                echo "Error: -m/--keeptemporaryfilesy must be yes or no."
                usage
            elif [[ -n "$show_chrY" && "$show_chrY" == "no" ]]; then
                chrom_list_Y=""
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

########################################################################
###                    Extract trio info from ped (silent)          ###
########################################################################
# Check if the file exists
if [ -f $pedfile ]; then
    # Read the line from the file
    line=$(cat "$pedfile")

    # Count the number of elements
    num_elements=$(echo $line | awk '{print NF}')

    # Check that there are exactly 6 elements
    if [ "$num_elements" -eq 6 ]; then
        read -r family proband father mother sexproband diseasestatut <<< "$line"
    else
        echo "Error: The line in the ped file does not contain exactly 6 elements."
        exit 1
    fi
else
    echo "Error: The ped file does not exist."
    exit 1
fi

########################################################################
###                    Display of parsed options                     ###
########################################################################
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
echo "family:               $family"
echo "naming_chr:           $naming_chr"
echo "read depth:           $readdepth"
echo "keep created files:   $overwritefiles"
echo "threads:              $threads"
echo "Output directory:     ${family}_UPDgraph_output"
echo -e "###############################\n"

########################################################################
###                    Extract trio info from ped                    ###
########################################################################
echo ">> Extract trio info from ped "
echo "family: $family"
echo "proband: $proband"
echo "father: $father "
echo "mother: $mother"
echo "sex proband: $sexproband"
echo "disease statut: $diseasestatut"

########################################################################
###                    Create output directory                       ###
########################################################################
echo ">> Create output directory"

# Create output directory based on family name
output_dir="${family}_UPDgraph_output"

# Remove existing directory if overwrite is enabled
if [ -d "$output_dir" ] && [ "$overwritefiles" = "yes" ]; then
    rm -rf "$output_dir"
    echo "Existing output directory removed: $output_dir"
fi

# Create the output directory
mkdir -p "$output_dir"
echo "Output directory created: $output_dir"
echo "All output files will be placed in: $output_dir"

########################################################################
###                  Fasta file or chromosome sizes                  ###
########################################################################
# chrom_list_noY
# $chrom_list_Y

printf %31s"\n" |tr " " "#"
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
if [ -f "$index_file" ] && [ "$overwritefiles" = "yes" ]; then
    rm "$index_file"
    echo "Index file removed."
else
    echo "Index file already exists: $index_file"
fi

if [ ! -f "$index_file" ]; then
    bcftools index --threads "$threads" "$inputfile"
    echo "Index created: $index_file"
fi

printf %31s"\n" |tr " " "#"
########################################################################
###                Extract trio samples from bcf/vcf                 ###
########################################################################
# extract the trio samples from a multi-sample vcf and reorder the vcf if required
echo ">> Extract trio samples from bcf/vcf"

# output file name (with output directory path)
trio_vcf_file="$output_dir/$family.$proband.bcf"

# Get the list of samples in the VCF/BCF file
vcf_samples=$(bcftools query -l "$inputfile")

# Check if each sample exists in the VCF/BCF file
found_all_samples=""
for sample in $proband $father $mother; do
    if echo "$vcf_samples" | grep -q "^$sample$"; then
        echo "Sample $sample exists in the initial file $inputfile."
    else
        echo "Sample $sample does not exist in the file $inputfile."
        found_all_samples="no"
    fi
done

if [[ $found_all_samples != "no" ]]; then
  if [ -f "$trio_vcf_file" ] && [ "$overwritefiles" = "yes" ]; then
      rm "$trio_vcf_file"
      echo "'Trio vcf file' is removed."
  fi
  if [ ! -f "$trio_vcf_file" ]; then
    echo "Extracting trio from $inputfile to 'Trio vcf file': $trio_vcf_file"
    nbPASS=$(bcftools query -f "QUAL\n" "$inputfile" | grep -c "PASS" )
    if [[ "$nbPASS" -gt 0 ]]; then
        echo "Field QUAL=PASS is detected"
        bcftools view --threads "$threads" -f PASS -s "$proband","$father","$mother" -r "$chrom_list_noY","$chrom_list_Y" "$inputfile" | bcftools norm --multiallelics - | awk '{if ($0 ~ /\t[0-9]\|[0-9]:/) gsub(/\|/, "/"); print}' | bcftools view -Ob -o "$trio_vcf_file"
    else
        echo "no field QUAL=PASS"
        bcftools view --threads "$threads" -s "$proband","$father","$mother" -r "$chrom_list_noY","$chrom_list_Y" "$inputfile" | bcftools norm --multiallelics - | awk '{if ($0 ~ /\t[0-9]\|[0-9]:/) gsub(/\|/, "/"); print}' | bcftools view -Ob -o "$trio_vcf_file"
    fi
    echo "'Trio vcf file' is created: $trio_vcf_file"
  fi
else
  echo "Not all samples are found in the vcf file"
  exit 1
fi

printf %31s"\n" |tr " " "#"
########################################################################
###                        Index trio bcf file                       ###
########################################################################
echo ">> Index trio bcf file"

# Remove previous file if necessary
if [ -f "${trio_vcf_file}.csi" ] && [ "$overwritefiles" = "yes" ]; then
  rm "${trio_vcf_file}.csi"
  echo "'Index trio bcf file' is removed."
fi
if [ ! -f "${trio_vcf_file}.csi" ]; then
  bcftools index --threads "$threads" "$trio_vcf_file"
fi

printf %31s"\n" |tr " " "#"
########################################################################
###          Analyse trio vcf and report variants of interest        ###
########################################################################
echo ">> Analyse trio vcf and report variants of interest"

variant_heredity_file="$output_dir/${family}.${proband}.DP${readdepth}.heredity_type.txt"

# erase file content if existing
truncate -s 0 "$variant_heredity_file"

# Variants inherited only from Father
# 1/1 1/1 0/0
# 1/1 0/1 0/0
# 0/0 0/1 1/1
# 0/0 0/0 1/1
bcftools view --threads "$threads" -r $chrom_list_noY -Ou "$trio_vcf_file" | bcftools view --threads "$threads" -Ou  -i "FORMAT/DP[0] > $readdepth && FORMAT/DP[1] > $readdepth && FORMAT/DP[2] > $readdepth" | bcftools view --threads "$threads" -Ou -i '(FORMAT/GT[0] == "1/1" && FORMAT/GT[1] == "1/1" && FORMAT/GT[2] == "0/0") || (FORMAT/GT[0] == "1/1" && FORMAT/GT[1] == "0/1" && FORMAT/GT[2] == "0/0") || (FORMAT/GT[0] == "0/0" && FORMAT/GT[1] == "0/1" && FORMAT/GT[2] == "1/1") || (FORMAT/GT[0] == "0/0" && FORMAT/GT[1] == "0/0" && FORMAT/GT[2] == "1/1") ' | bcftools query -f "%CHROM\t%POS\tFF\n" | sed 's/^chr//' >> $variant_heredity_file

# Variants inherited only from Mother
# 1/1 0/0 1/1
# 1/1 0/0 0/1
# 0/0 1/1 0/1
# 0/0 1/1 0/0
bcftools view --threads "$threads" -r $chrom_list_noY -Ou "$trio_vcf_file" | bcftools view --threads "$threads" -Ou  -i "FORMAT/DP[0] > $readdepth && FORMAT/DP[1] > $readdepth && FORMAT/DP[2] > $readdepth" | bcftools view --threads "$threads" -Ou -i '(FORMAT/GT[0] == "1/1" && FORMAT/GT[1] == "0/0" && FORMAT/GT[2] == "1/1") || (FORMAT/GT[0] == "1/1" && FORMAT/GT[1] == "0/0" && FORMAT/GT[2] == "0/1") || (FORMAT/GT[0] == "0/0" && FORMAT/GT[1] == "1/1" && FORMAT/GT[2] == "0/1") || (FORMAT/GT[0] == "0/0" && FORMAT/GT[1] == "1/1" && FORMAT/GT[2] == "0/0")' | bcftools query -f "%CHROM\t%POS\tFM\n" | sed 's/^chr//' >> "$variant_heredity_file"

# From both parents
# 0/1 1/1 0/0
# 0/1 0/0 1/1
bcftools view --threads "$threads" -r $chrom_list_noY -Ou "$trio_vcf_file" | bcftools view --threads "$threads" -Ou  -i "FORMAT/DP[0] > $readdepth && FORMAT/DP[1] > $readdepth && FORMAT/DP[2] > $readdepth" | bcftools view --threads "$threads" -Ou -i '(FORMAT/GT[0] == "0/1" && FORMAT/GT[1] == "1/1" && FORMAT/GT[2] == "0/0") || (FORMAT/GT[0] == "0/1" && FORMAT/GT[1] == "0/0" && FORMAT/GT[2] == "1/1")' | bcftools query -f "%CHROM\t%POS\tBP\n" | sed 's/^chr//' >> "$variant_heredity_file"

# For chrY
# 1/1 1/1 -/-
if [[ $chrom_list_Y != "" ]]; then
    bcftools view --threads "$threads" -r $chrom_list_Y -Ou "$trio_vcf_file" | bcftools view --threads "$threads" -Ou  -i "FORMAT/DP[0] > $readdepth && FORMAT/DP[1] > $readdepth && FORMAT/DP[2] < $((readdepth/2))" | bcftools view --threads "$threads" -Ou -i '(FORMAT/GT[0] == "1/1" && FORMAT/GT[1] == "1/1" && FORMAT/GT[2] != "0/1") || (FORMAT/GT[0] == "1/1" && FORMAT/GT[1] == "1/1" && FORMAT/GT[2] != "1/1")' | bcftools query -f "%CHROM\t%POS\tFF\n" | sed 's/^chr//' >> "$variant_heredity_file"
fi

printf %31s"\n" |tr " " "#"
########################################################################
###                       Get vcf for proband                        ###
########################################################################
echo ">> Get vcf for proband"

if [ -f "$output_dir/${proband}.proband.vcf" ] && [ "$overwritefiles" = "yes" ]; then
  rm "$output_dir/${proband}.proband.vcf"
  echo "'proband vcf file' is removed."
fi

if [ ! -f "$output_dir/${proband}.proband.vcf" ]; then
  nbPASS=$(bcftools query -f "QUAL\n" "$trio_vcf_file" | grep -c "PASS" )
  if [[ "$nbPASS" -gt 0 ]]; then
      echo "Field QUAL=PASS is detected"
      bcftools view --threads "$threads" -Ov -f PASS -s "$proband" -r "$chrom_list_noY","$chrom_list_Y" "$trio_vcf_file" > "$output_dir/${proband}.proband.vcf"
  else
      echo "no field QUAL=PASS"
      bcftools view --threads "$threads" -Ov -s "$proband" -r "$chrom_list_noY","$chrom_list_Y" "$trio_vcf_file" > "$output_dir/${proband}.proband.vcf"
  fi
fi

printf %31s"\n" |tr " " "#"
########################################################################
###                           Run Automap                            ###
########################################################################
echo ">> Run Automap"

# Remove previous ROH dir if necessary
if [ -r "$output_dir/${proband}.ROH" ] && [ "$overwritefiles" = "yes" ]; then
  rm -r "$output_dir/${proband}.ROH"
  echo -e "Directory $output_dir/${proband}.ROH is removed."
fi

if [ ! -f "$output_dir/${proband}.ROH/${proband}.ROH.HomRegions.tsv" ]; then
  if [[ -n "$genome" && ("$genome" == "hg19" || "$genome" == "hg38") ]]; then
      roh_file="$output_dir/${proband}.ROH/${proband}.ROH.HomRegions.tsv"
      bash $AUTOMAP_HOME/AutoMap_v1.3.1.sh --minsize 3 --vcf "$output_dir/${proband}.proband.vcf" --id "${proband}.ROH" --out "$output_dir" --genome "$genome" --chrX || roh_file=""
  else
      roh_file=""
  fi
else
  roh_file="$output_dir/${proband}.ROH/${proband}.ROH.HomRegions.tsv"
fi

printf %31s"\n" |tr " " "#"
########################################################################
###                          Make the plot                           ###
########################################################################
echo ">> Make the plot"

python $UPDgraph_py_HOME/UPDgraph.py --file "$variant_heredity_file" --roh "$roh_file" -n "$naming_chr" -g "$genome" -o "$output_dir/$output"

printf %31s"\n" |tr " " "#"
########################################################################
###                      Remove temporary file                       ###
########################################################################

if [[ "$keeptemporaryfiles" == "no" ]]; then
     rm "$trio_vcf_file"
     rm "${trio_vcf_file}.csi"
     rm "$variant_heredity_file"
     rm "$output_dir/${proband}.proband.vcf"
     if [ -d "$output_dir/${proband}.ROH" ]; then
       rm -r "$output_dir/${proband}.ROH"
     fi
fi

########################################################################
###                 Change permissions on all files                  ###
########################################################################
if [ -f "$trio_vcf_file" ]; then
    chmod 774 "$trio_vcf_file"
fi
if [ -f "${trio_vcf_file}.csi" ]; then
    chmod 774 "${trio_vcf_file}.csi"
fi
if [ -f "$variant_heredity_file" ]; then
    chmod 774 "$variant_heredity_file"
fi
if [ -f "$output_dir/${proband}.proband.vcf" ]; then
    chmod 774 "$output_dir/${proband}.proband.vcf"
fi
if [ -d "$output_dir/${proband}.ROH" ]; then
    chmod -R 774 "$output_dir/${proband}.ROH"
fi

printf %31s"\n" |tr " " "#"
########################################################################
###                            Terminate                             ###
########################################################################

echo "-- Processing complete --"
echo "All output files are located in: $output_dir"