# Ensure correct number of arguments

if [ "$#" -ne 5 ]; then
    echo "Usage: $0 path_to_fasta_file path_to_count_table_file path_to_usearch path_to_mothur path_to_silva"
    exit 1
fi

# Assign arguments to variables

fasta_file="$1"
count_table="$2"
USEARCH="$3"
MOTHUR="$4"
SILVA="$5"

# Debugging: Print out paths

echo "USEARCH Path: $USEARCH"
echo "Mothur Path: $MOTHUR"
echo "Silva Path: $SILVA"

# Check if the Silva database file is provided

if [ -z "$SILVA" ]; then
    echo "Please specify the path to the Silva database file."
    exit 1
fi

# Check if the executables exist

if [ ! -x "$USEARCH" ]; then
    echo "USEARCH executable not found or is not executable."
    exit 1
fi

if [ ! -x "$MOTHUR" ]; then
    echo "Mothur executable not found or is not executable."
    exit 1
fi

# Extract filename without extension from fasta file path

filename=$(basename -- "$fasta_file")
filename_no_ext="${filename%.*}"

# Output file with updated headers

output_file="output_${filename_no_ext}.fasta"

# Clear contents of output file

> "$output_file"

# Create an associative array to store size and abundance information

declare -A sizes

# Read count table and populate the arrays

while IFS=$'\t' read -r seq_id size; do
    sizes["$seq_id"]=$size
done < "$count_table"

# Process the FASTA file and update headers

while IFS= read -r line; do
    if [[ $line == ">"* ]]; then
        seq_id="${line:1}" # Remove the ">" character

        # Remove the numbers between parentheses in the size value

        size_no_numbers="${sizes[$seq_id]//*,/}"

        new_header=">${seq_id};size=${size_no_numbers}"

        echo "$new_header" >> "$output_file"
    else
        echo "$line" >> "$output_file"
    fi
done < "$fasta_file"

echo "Headers updated with size information (numbers between parentheses removed) in $output_file."

# Run UCHIME3 based on USEARCH

echo "Running USEARCH3 with the following command:"
echo "$USEARCH -uchime3_denovo \"$output_file\" -chimeras ch_${filename_no_ext}.fa -nonchimeras nonch_${filename_no_ext}.fa"
$USEARCH -uchime3_denovo "$output_file" -chimeras ch_${filename_no_ext}.fa -nonchimeras nonch_${filename_no_ext}.fa

# Check if USEARCH3 output files are created

if [ ! -f "ch_${filename_no_ext}.fa" ] || [ ! -f "nonch_${filename_no_ext}.fa" ]; then
    echo "Error: USEARCH3 did not produce the expected output files."
else
    echo "USEARCH3 execution complete. Output files created: ch_${filename_no_ext}.fa, nonch_${filename_no_ext}.fa"
fi

# Check if the file exists before running other tools

if [ -f "$output_file" ]; then
    # Align sequences using Mothur (adjust this command based on your actual usage)

    "$MOTHUR" "#align.seqs(fasta=$output_file, reference=$SILVA)"

    # Construct the name of the align output file

    ALIGN_FILE="${output_file%.fasta}.align"

    # Run chimera detection methods with Mothur

    "$MOTHUR" "#chimera.slayer(fasta=$ALIGN_FILE, count=$count_table, reference=self)"
    "$MOTHUR" "#chimera.perseus(fasta=$ALIGN_FILE, count=$count_table)"
    "$MOTHUR" "#chimera.uchime(fasta=$ALIGN_FILE, count=$count_table)"
    "$MOTHUR" "#chimera.vsearch(fasta=$ALIGN_FILE, count=$count_table)"

    echo "Chimera detection complete for $output_file."
else
    echo "No matching .count_table file found for $output_file"
fi
