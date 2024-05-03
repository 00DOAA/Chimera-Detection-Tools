#!/bin/bash

# Usage: bash script_name.sh path_to_fasta_directory path_to_count_table_directory

# This script processes FASTA files and count tables located in the specified directories.
# It updates headers in the FASTA files with size information and performs chimera detection using USEARCH and Mothur.

# Arguments:
# - path_to_fasta_directory: Path to the directory containing FASTA files (e.g., /path/to/fasta_directory)
# - path_to_count_table_directory: Path to the directory containing count tables (e.g., /path/to/count_table_directory)

# Example usage:
# bash script_name.sh /path/to/fasta_directory /path/to/count_table_directory

# Ensure that the paths provided contain the necessary FASTA files and count tables for processing.

# Define the paths to the Mothur and USEARCH executables
MOTHUR="/home/user/mothur"
USEARCH="/home/user/usearch"
SILVA="/home/user/silva.fasta"

# Check if the Silva database file is provided
if [ -z "$SILVA" ]; then
  echo "Please specify the Silva database file."
  exit 1
fi

# Define the list of numbers
numbers=(5 12 13 15 18 19 20 21 22 23)

# Loop through the specified numbers and process the corresponding FASTA files and count tables
for i in "${numbers[@]}"; do
  fasta_file="$1/mock${i}.fasta"
  count_table="$2/mock${i}.count_table"
  output_file="output${i}.fasta"

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
  $USEARCH -uchime3_denovo "$output_file" -chimeras ch_${i}.fa -nonchimeras nonch_${i}.fa
  echo "Chimera detection complete for $output_file."

  # Check if the file exists before running other tools
  if [ -f "$output_file" ]; then
    # Align sequences using Mothur (adjust this command based on your actual usage)
    $MOTHUR "#align.seqs(fasta=$output_file, reference=$SILVA)"
    # Construct the name of the align output file
    ALIGN_FILE="${output_file%.fasta}.align"

    # Run chimera detection methods with Mothur
    $MOTHUR "#chimera.slayer(fasta=$ALIGN_FILE, count=$count_table, reference=self)"
    $MOTHUR "#chimera.perseus(fasta=$ALIGN_FILE, count=$count_table)"
    $MOTHUR "#chimera.uchime(fasta=$ALIGN_FILE, count=$count_table)"
    $MOTHUR "#chimera.vsearch(fasta=$ALIGN_FILE, count=$count_table)"
    echo "Chimera detection complete for $output_file."
  else
    echo "No matching .count_table file found for $output_file"
  fi
done

