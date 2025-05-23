import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, Circle
from matplotlib.lines import Line2D
import argparse

########################################################################################################################
##>  Define parser and subparser
########################################################################################################################
parser = argparse.ArgumentParser()
parser.add_argument("-v", "--verbose", help="""verbose level from 1 (low verbose) to 3 (high verbose)""", type=int, choices=[1, 2, 3])
# parser.add_argument("-c", "--chromosomes", help="""fasta file or chromosome size""", type=str)
parser.add_argument("-g", "--genome", help="""Select human genome among hg19, hg38 and T2T""", type=str, required=True)
parser.add_argument("-f", "--file", help="""report FF FM BP""", type=str, required=True)
parser.add_argument("-o", "--output", help="""filename of the .png output file""", type=str, default="ideogram.updgraph.png")
parser.add_argument("--roh", help="""ROH tsv file generated with automap""", type=str)
parser.add_argument("-n", "--naming_chr", help="""specify a name to use for chromosome naming in the plot (e.g. "chr"); default is without 'chr' """, type=str)


########################################################################################################################
##>  Parse arguments
########################################################################################################################
args = parser.parse_args()

file = args.file
output = args.output

genome = args.genome

if args.roh:
    roh_file = args.roh
else:
    roh_file = ""

if args.naming_chr:
    naming_chr = args.naming_chr
else:
    naming_chr = ""

########################################################################################################################
##>  Variables
########################################################################################################################


scale_factor = 10000000

########################################################################################################################
##>  Anala
########################################################################################################################

# Data (chr, first rectangle, second rectangle)
chromosomes = {"hg19" : [
        ('1', 249250621, 125000000),
        ('2', 243199373, 93300000),
        ('3', 198022430, 91000000),
        ('4', 191154276, 50400000),
        ('5', 180915260, 48400000),
        ('6', 171115067, 61000000),
        ('7', 159138663, 59900000),
        ('8', 146364022, 45600000),
        ('9', 141213431, 49000000),
        ('10', 135534747, 40200000),
        ('11', 135006516, 53700000),
        ('12', 133851895, 35800000),
        ('13', 115169878, 17900000),
        ('14', 107349540, 17600000),
        ('15', 102531392, 19000000),
        ('16', 90354753, 36600000),
        ('17', 81195210, 24000000),
        ('18', 78077248, 17200000),
        ('19', 59128983, 26500000),
        ('20', 63025520, 27500000),
        ('21', 48129895, 13200000),
        ('22', 51304566, 14700000),
        ('X', 155270560, 60600000),
        ('Y', 59373566, 12500000)
    ],
    "hg38": [
        ('1', 248956422, 123400000),
        ('2', 242193529, 93900000),
        ('3', 198295559, 90900000),
        ('4', 190214555, 50000000),
        ('5', 181538259, 48800000),
        ('6', 170805979, 59800000),
        ('7', 159345973, 60100000),
        ('8', 145138636, 45200000),
        ('9', 138394717, 43000000),
        ('10', 133797422, 39800000),
        ('11', 135086622, 53400000),
        ('12', 133275309, 35500000),
        ('13', 114364328, 17700000),
        ('14', 107043718, 17200000),
        ('15', 101991189, 19000000),
        ('16', 90338345, 36800000),
        ('17', 83257441, 25100000),
        ('18', 80373285, 18500000),
        ('19', 58617616, 26200000),
        ('20', 64444167, 28100000),
        ('21', 46709983, 12000000),
        ('22', 50818468, 15000000),
        ('X', 156040895, 61000000),
        ('Y', 57227415, 10400000)
    ],
    "T2T": [
        ('1', 248387328, 124048267),
        ('2', 242696752, 93503283),
        ('3', 201105948, 94076514),
        ('4', 193574945, 52452474),
        ('5', 182045439, 48317879),
        ('6', 172126628, 59672548),
        ('7', 160567428, 62064435),
        ('8', 146259331, 45270456),
        ('9', 150617247, 46267185),
        ('10', 134758134, 40649191),
        ('11', 135127769, 52743313),
        ('12', 133324548, 35911664),
        ('13', 113566686, 16522942),
        ('14', 101161492, 11400261),
        ('15', 99753195, 17186630),
        ('16', 96330374, 36838903),
        ('17', 84276897, 25689679),
        ('18', 80542538, 18449624),
        ('19', 61707364, 27792923),
        ('20', 66210255, 28012753),
        ('21', 45090682, 11134529),
        ('22', 51324926, 14249622),
        ('X', 154259566, 59373565),
        ('Y', 62460029, 10724418)
    ]
}

dict_color_and_coord = {
    'BP': {
        'color': 'silver',
        'ymin': -0.11,
        "ymax": 0.11,
    },
    'FF': {
        'color': '#0061E5',
        'ymin': -0.125,
        "ymax": -0.475,
    },
    'FM': {
        'color': '#C6003F',
        'ymin': 0.125,
        "ymax": 0.475,
    },
    'ROH': {
        'color': 'mediumaquamarine',
        'ymin': 0.0,
        "ymax": 0.15,
    }
}

########################################################################################################################
##>  Initialize dict_pos
########################################################################################################################
# Insert heredity types
dict_pos = {'BP': {}, 'FF': {}, 'FM': {}}

# Verify chromosome names in file ?
# >>

# Insert chromosome names for each heredity type
for chrom, start, end in chromosomes[genome]:
    chrom_name = str(chrom)
    for heredity_type in dict_pos:
        dict_pos[heredity_type][chrom_name] = {}

########################################################################################################################
##>  Load data from bcftools sorting
########################################################################################################################

with open(file, "r") as IN:
    for line in IN:
        # print(line)
        line = line.rstrip('\r\n')
        if line.isspace():
            continue
        elif line == "":
            continue
        elif line.startswith("#"):
            continue
        else:
            line = '\t'.join(line.split())
            interm_array = line.split("\t")
            interm_array[0] = interm_array[0].replace("Chr", "").replace("chr", "")
            converted_pos = float(f"{int(interm_array[1]) / scale_factor:.3f}")
            dict_pos[ interm_array[2] ][ interm_array[0] ][ converted_pos ] = "x"

# print(dict_pos)

########################################################################################################################
##>  Load ROH data
########################################################################################################################
dict_roh = {}

if roh_file != "":
    with open(roh_file, "r") as IN:
        for line in IN:
            # print(line)
            line = line.rstrip('\r\n')
            if line.isspace():
                continue
            elif line == "":
                continue
            elif line.startswith("#"):
                continue
            else:
                line = '\t'.join(line.split())
                interm_array = line.split("\t")
                interm_array[0] = interm_array[0].replace("Chr", "").replace("chr", "")
                interm_array[1] = float(f"{int(interm_array[1]) / scale_factor:.3f}")
                interm_array[2] = float(f"{int(interm_array[2]) / scale_factor:.3f}")
                #            chrom              start              stop
                if  interm_array[0] not in dict_roh:
                    dict_roh[ interm_array[0] ] = {}
                if interm_array[1] not in dict_roh[ interm_array[0] ]:
                    dict_roh[ interm_array[0] ][ interm_array[1] ] = {}
                dict_roh[ interm_array[0] ][ interm_array[1] ][ interm_array[2] ] = "x"

    print(dict_roh)

########################################################################################################################
##>  Plot
########################################################################################################################

# Create plot ands axes
fig, ax = plt.subplots(figsize=(12, 18))

# Dimensions of rectangles
height_rect = 1
dist_between_rects = 1.5  # Space between chromosomes
radius_rect_tip = 0.5  # Radius of the circle applied to rectangle tips
diameter_centromere_circle = height_rect / 4
radius_centromere_circle = diameter_centromere_circle / 2

# Initial positions
x1 = 0
y = 0
y_circle = 0

filtered_variants = {
    'BP': 0,
    'FF': 0,
    'FM': 0
}
total_variants = {
    'BP': 0,
    'FF': 0,
    'FM': 0
}

# loop to add all chromosomes
for chr_name, length_chr, centro in chromosomes[genome]:
        chr_name_plot = naming_chr + str(chr_name)
        ax.text(x1 - 1, y - 0.200, chr_name_plot, fontsize=14, ha='right')

        centro_norm = centro / scale_factor
        length_chr_norm = length_chr / scale_factor

        # width_rect_1 = centro_norm - radius - radius_centromere_circle
        # width_rect_2 = length_chr_norm - (centro_norm + radius + radius_centromere_circle)

        width_rect_1 = centro_norm - radius_centromere_circle
        width_rect_2 = length_chr_norm - centro_norm - radius_centromere_circle

        # First rectangle (before centromere)
        rect1 = FancyBboxPatch((x1, y - height_rect / 2),
                            width_rect_1, height_rect, boxstyle=f"round,pad=0,rounding_size={radius_rect_tip}",
                            edgecolor="silver",
                            linewidth=1.5,
                            facecolor="whitesmoke")

        # Position of second rectangle
        x2 = x1 + width_rect_1 + diameter_centromere_circle

        # Second rectangle (after centromere)
        rect2 = FancyBboxPatch((x2, y - height_rect / 2),
                            width_rect_2, height_rect, boxstyle=f"round,pad=0,rounding_size={radius_rect_tip}",
                            edgecolor="silver",
                            linewidth=1.5,
                            facecolor="whitesmoke")

        # Circle (centromere)
        x_cercle = x1 + width_rect_1 + radius_centromere_circle
        cercle = Circle((x_cercle, y_circle), radius_centromere_circle, facecolor="silver",edgecolor="silver",linewidth=0.1)

        # Add shapes to plot
        ax.add_patch(rect1)
        ax.add_patch(rect2)
        ax.add_patch(cercle)

        # Draw colored bars
        for heredity_type in dict_pos:
            for position in dict_pos[heredity_type][chr_name]:
                total_variants[heredity_type] += 1
                if x1 + (radius_rect_tip/2) <= position <= x1 + width_rect_1 - (radius_rect_tip/2):
                    ax.vlines(position,
                            ymin=y + dict_color_and_coord[heredity_type]["ymin"], ymax=y + dict_color_and_coord[heredity_type]["ymax"], colors=dict_color_and_coord[heredity_type]["color"],
                            linewidth=0.8,
                            alpha=0.5)
                elif x2 + (radius_rect_tip/2) <= position <= x2 + width_rect_2 - (radius_rect_tip/2):
                    ax.vlines(position,
                            ymin=y + dict_color_and_coord[heredity_type]["ymin"], ymax=y + dict_color_and_coord[heredity_type]["ymax"], colors=dict_color_and_coord[heredity_type]["color"],
                            linewidth=0.8,
                            alpha=0.5)
                else:
                    filtered_variants[heredity_type] += 1
                # print(heredity_type, chr, position)
                # input()
                #ax.vlines(position, ymin=y + dict_color_and_coord[heredity_type]["ymin"], ymax=y + dict_color_and_coord[heredity_type]["ymax"], colors=dict_color_and_coord[heredity_type]["color"], linewidth=0.8,alpha=0.5)

        # ROH rectangles
        if chr_name in dict_roh:
            for p1 in dict_roh[chr_name]:
                for p2 in dict_roh[chr_name][p1]:
                    p1_plot = p1
                    p2_plot = p2
                    if p1 <= x1 + (radius_rect_tip/2):
                        p1_plot = x1 + (radius_rect_tip/2)
                    if p2 >= x2 + width_rect_2 - (radius_rect_tip/2):
                        p2_plot = x2 + width_rect_2 - (radius_rect_tip/2)

                    rectROH = FancyBboxPatch((x1 + p1_plot, y + height_rect/2),
                                        width=p2_plot - p1_plot,
                                        height=dict_color_and_coord['ROH']["ymax"] - dict_color_and_coord['ROH']["ymin"],
                                        boxstyle=f"square,pad=0",
                                        edgecolor="none",
                                        linewidth=1.5,
                                        facecolor=dict_color_and_coord['ROH']["color"])
                    ax.add_patch(rectROH)

        # Premier rectangle (before centromere)
        rect1 = FancyBboxPatch((x1, y - height_rect / 2),
                            width_rect_1, height_rect, boxstyle=f"round,pad=0,rounding_size={radius_rect_tip}",
                            edgecolor="silver",
                            linewidth=1.5,
                            facecolor="none",
                            zorder=10 )

        # Position of second rectangle
        x2 = x1 + width_rect_1 + diameter_centromere_circle

        # Second rectangle (after centromere)
        rect2 = FancyBboxPatch((x2, y - height_rect / 2),
                            width_rect_2, height_rect, boxstyle=f"round,pad=0,rounding_size={radius_rect_tip}",
                            edgecolor="silver",
                            linewidth=1.5,
                            facecolor="none",
                            zorder=10 )



        # Ajust positions for next chromosome
        y = y - dist_between_rects
        y_circle = y_circle - dist_between_rects

        # Add shapes to plot
        ax.add_patch(rect1)
        ax.add_patch(rect2)

# Set up display limits
ax.set_xlim(-2, 28)
ax.set_ylim(-35.5, 2)
ax.set_aspect('equal')

# Suppress axes
ax.axis('off')

# Add legend
legend_elements = [
    Line2D([0], [0], marker='o', color=dict_color_and_coord["FM"]["color"], label='Maternal', markerfacecolor=dict_color_and_coord["FM"]["color"], markersize=5),
    Line2D([0], [0], marker='o', color=dict_color_and_coord["FF"]["color"], label='Paternal', markerfacecolor=dict_color_and_coord["FF"]["color"], markersize=5),
    Line2D([0], [0], marker='o', color=dict_color_and_coord["BP"]["color"], label='Biparental', markerfacecolor=dict_color_and_coord["BP"]["color"], markersize=5),
    Line2D([0], [0], marker='o', color=dict_color_and_coord["ROH"]["color"], label='ROH regions', markerfacecolor=dict_color_and_coord["ROH"]["color"], markersize=5)
]
ax.legend(handles=legend_elements, loc='lower right')

# Record plot as png file
plt.savefig(output, bbox_inches='tight', dpi=300)

print(f"Total variants: {sum(total_variants.values())}")
print(f"Variants removed (chromomose tips and centromere): {sum(filtered_variants.values())}")
