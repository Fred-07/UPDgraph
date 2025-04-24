# UPDgraph

UPDgraph is a software tool for detecting Uniparental Disomies (UPDs) from trio exome or genome VCF files. The tool generates ideogram plots representing the parental origin of single nucleotide variants along with Runs of Homozygosity (ROH), enabling easy and visual detection of UPDs.

## Overview & Features

UPDgraph operates as follows:

- Extracts the trio (child, father, mother) from a multi-sample VCF/BCF file based on a PED file
- Uses BCFtools to sort variants based on their inheritance pattern
- Runs AutoMap to identify ROH (for hg19/hg38 genomes only)
- Generates comprehensive ideogram plots combining all the information

Key features:
- Works with standard VCF/BCF files containing child, father, and mother genotype 
- Compatible with hg19, hg38, and T2T reference genomes
- Run via Singularity, Docker, or locally

![Example UPDgraph output](https://github.com/Fred-07/UPDgraph/images/example_output.png)


## Installation

UPDgraph can be installed and run in three different ways:

### Option 1: Using Singularity (Recommended)

```bash
# Clone the repository
git clone https://github.com/Fred-07/UPDgraph.git
cd UPDgraph

# Build the Singularity container
singularity build UPDgraph.sif UPDgraph_singularity.def

# Run UPDgraph using Singularity
singularity exec -B $PWD UPDgraph.sif bash UPDgraph.sh --vcf trio.vcf.gz -p family.ped -g hg19 -o output.png
```

### Option 2: Using Docker

```bash
# Clone the repository
git clone https://github.com/Fred-07/UPDgraph.git
cd UPDgraph

# Build the Docker container ?????? Demander à VY
docker build -t UPDgraph .

# Run UPDgraph using Docker ?????? Demander à VY
docker run -v $(pwd):/data UPDgraph bash UPDgraph.sh --vcf trio.vcf.gz -p family.ped -g hg19 -o output.png
```

### Option 3: Local Installation

Prerequisites:
- Python 3+ with basic libraries: matplotlib, argparse
- BCFtools (v1.13+)
- AutoMap Fork (https://github.com/Fred-07/AutoMap)
	- BEDTools (v2.30.0+)
	- R (v3.5+)
	- Perl (v5.22+)


```bash
# Clone the repository
git clone https://github.com/Fred-07/UPDgraph.git

# Clone AutoMap if not already installed
git clone https://github.com/Fred-07/AutoMap.git

# Run UPDgraph locally
bash ./UPDgraph/UPDgraph.sh --vcf sample.vcf.gz -p family.ped -g hg19 -a ./AutoMap/ -u ./UPDgraph/ -o output.png 
```

**Note**: For local installation, specify the path to AutoMap (-a) and UPDgraph (-u) in the command.


## Usage

Regardless of the installation method, UPDgraph is used with the same basic command structure:

```bash
bash UPDgraph.sh --vcf <vcf_file> -p <pedfile> -g <genome> -o <output_file> [options]
```

### Required Arguments:
- `--vcf`: Path to the multi-sample VCF file
- `-p, --pedfile`: Path to PED file containing family information (single line)
- `-g, --genome`: Human genome version (hg19, hg38, or T2T)
- `-o, --output`: Filename for the output PNG file (default: 'plot.png')

### Optional Arguments:
- `-v, --verbose`: Verbosity level from 1 (low) to 3 (high) (default: 1)
- `-n, --naming_chr`: Specify a prefix for chromosome naming in the plot (e.g., 'chr') (default: '')
- `-r, --readdepth`: Minimum read depth to consider a position (default: 8)
- `-k, --keepcreatedfiles`: Keep the existing files created with UPDgraph (default: 'yes')
- `-t, --threads`: Number of threads to use with bcftools (default: 1)
- `-u, --UPDgraph_py_HOME`: Specify the path for UPDgraph.py (default: '/opt/UPDgraph/')
- `-a, --AUTOMAP_HOME`: Specify the path for automap_vx.x.x.sh (default: '/opt/AutoMap/')


## Input Files

### VCF Requirements
- Multi-sample VCF/BCF file containing the trio (child, father, mother)
- Samples must correspond to the names specified in the PED file

### PED File Format

- The PED file should contain a single line with 6 tab-separated fields:
```
FamilyID  Proband  Father  Mother  Sex  DiseaseStatus
```

- Example:
```
FAM001  CHILD001  FATHER001  MOTHER001  1  2
```

- Where:
	- Sex: 1=male, 2=female, 0=unknown
	- DiseaseStatus: 1=unaffected, 2=affected (not used by UPDgraph)

## Output and Interpretation

UPDgraph generates an ideogram plot file with the specified output name showing:
- Parental origin of variants across chromosomes (color-coded):
  - **Red**: Maternal origin
  - **Blue**: Paternal origin
  - **Gray**: Biparental (inherited from both parents)
- ROH regions (if using hg19 or hg38 genome references) shown in green boxes above the chromosomes

### Interpreting Results

#### Interpreting Autosomes

- **Maternal UPD**: Predominance of red markers across an entire chromosome
- **Paternal UPD**: Predominance of blue markers across an entire chromosome
- **Segmental UPD**: Segment of a chromosome showing only maternal or paternal markers
- **Isodisomy**: UPD coinciding with ROH (green boxes)
- **Heterodisomy**: UPD without ROH

#### Interpreting Sex Chromosomes

- **Normal Female (XX)**: Mixture of gray (biparental), blue (paternal), and red (maternal) markers
- **Normal Male (XY)**: Predominantly red (maternal) markers since males inherit X from mother only
- **Abnormal Patterns**:
  - Female with predominantly or exclusively paternal X markers: Could indicate complete maternal X loss
  - Female with predominantly maternal X markers: May indicate paternal X chromosome loss
  - Male with blue (paternal) markers on X: Indicates abnormal X inheritance pattern

## License


This project is licensed under the [GPL-3.0 license](https://www.gnu.org/licenses/gpl-3.0.en.html) - see the LICENSE file for details.

## Acknowledgements
UPDgraph was developed at the Genetic Medicine Division, Hôpitaux Universitaires de Genève (HUG).

We thank:
- The developers of BCFtools, AutoMap, and other dependencies
- Our clinical genetics collaborators for valuable feedback
- Our bioinformatician colleagues for testing and suggestions

## Contact

For questions, support, or collaboration:
- GitHub Issues: https://github.com/Fred-07/UPDgraph/issues