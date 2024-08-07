#!/usr/bin/env python3
# Copyright (C) 2023 Genome Surveillance Unit/Genome Research Ltd.

import argparse
import csv
import json


class PlasmepsinVariantCaller:
    """
    Calls the breakpoint of the Plasmepsin 2/3 amplification in each of the supplied genotype files.
    Uses supplied genotypes and loci.
    Writes these plasmepsin variant calls to a single output file.

    Rationale behind implementation:
    1) Plasmepsin 2/3 amplification creates a hybrid gene sequence containing portions of plasmepsin 1 and plasmepsin 3.
    2) Wild type sequences and these chimeric sequences align to the plasmepsin 1 reference.
    3) However, the hybrid gene product causes several SNPs to appear as a result of the plasmepsin 3 portion.
    4) Genotyping at these nucleotides allows for amplification to be identified.
    """

    def __init__(self, genotype_files, out_file_name, config):
        self.genotype_file_list = genotype_files
        self.output_file_name = out_file_name
        self.config = config

    def call_plasmepsin_variants(self):
        """
        Process the plasmepsin breakpoint call from each per-sample genotype file.
        Amplification is called if alternative genotype (homozygous / heterozygous) is seen at any of the supplied positions.
        """

        with open(self.config) as file:
            plasmepsin_config = json.load(file).get("grc_plasmepsin")
            plasmepsin_loci = plasmepsin_config.get("plasmepsin_loci")

        output_file = open(self.output_file_name, "w")
        file_writer = csv.DictWriter(
            output_file, delimiter="\t", fieldnames=["ID", "P23:BP"]
        )
        file_writer.writeheader()

        # Iterate over the supplied per-sample genotype files
        for genotype_file_path in self.genotype_file_list:

            # Get all of the rows from this genotype file at plasmepsin loci
            plasmepsin_genotype_rows = self._get_plasmepsin_rows(
                genotype_file_path, plasmepsin_loci
            )
            # Iterate over all of the sample IDs in this genotype file
            sample_id_list = set(
                row.get("ID") for row in plasmepsin_genotype_rows.values()
            )
            for sample_id in sample_id_list:

                # Determine this sample's variant ("WT", "Copy" or "-")
                variant = self._determine_sample_variant(
                    sample_id, plasmepsin_genotype_rows, plasmepsin_loci
                )

                # Write variant and sample ID to output file
                row = {"ID": str(sample_id), "P23:BP": str(variant)}
                file_writer.writerow(row)

        output_file.close()

    def _get_plasmepsin_rows(self, genotype_file_path, plasmepsin_loci):
        """
        Returns a dictionary created from the the provided genotype file.
        Only adds to the dictionary genotype file rows that are at the plasmepsin loci.
        """
        plasmepsin_positions = [locus.get("Position") for locus in plasmepsin_loci]
        genotype_file_dict = {}
        genotype_file = open(genotype_file_path, newline="")
        for row in csv.DictReader(genotype_file, delimiter="\t"):

            # If this row is not a plasmepsin locus then ignore it
            if f"{row[str('Chr')]}:{row[str('Loc')]}" in plasmepsin_positions:

                # Key is chromosome:locus
                key = f"{row[str('ID')]}-{row[str('Chr')]}:{row[str('Loc')]}"

                # Value is a dictionary of that genotype file row
                genotype_file_dict[key] = dict(row)

        genotype_file.close()
        return genotype_file_dict

    def _determine_sample_variant(
        self, sample_id, plasmepsin_genotype_rows, plasmepsin_loci
    ):
        """
        Uses the genotypes at specified loci to determine the variant for a sample.
        """
        # Default variant for a sample is "WT" / wild type
        variant = "WT"
        missing_counter = 0

        # Iterate over all of the plasmepsin loci
        for locus in plasmepsin_loci:

            # Retrieve the relevant genotype call
            position = f"{sample_id}-{locus.get('Position')}"
            genotype_file_row = plasmepsin_genotype_rows.get(position)
            called_genotype = genotype_file_row.get("Gen")

            # Retrieve the alternate allele genotypes for this plasmepsin locus.
            alternate_allele_genotypes = locus.get("Genotypes")

            # If this locus has an alternate allele genotype then return amplification as the variant
            # Otherwise, continue looking at remaining loci for this sample
            if called_genotype in alternate_allele_genotypes:
                variant = locus.get("Variant")
                break

            # If the genotype call at this locus is missing then update the missing counter
            elif called_genotype == "-":
                missing_counter += 1

        # If the genotype calls at all of loci are missing then return variant as missing
        if missing_counter == len(plasmepsin_loci):
            variant = "-"
        return variant


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--genotype_files",
        "-i",
        help="List of per-sample genotype files to call plasmepsin variants in.",
        required=True,
        type=str,
        nargs="+",
        default=[],
    )

    parser.add_argument(
        "--output_file",
        "-o",
        help="Name for the output plasmepsin variants file. Default is plasmepsin_cnv_calls.txt.",
        type=str,
        default="plasmepsin_cnv_calls.txt",
    )

    parser.add_argument(
        "--config",
        "-l",
        help="Config JSON file containing a list of plasmepsin loci, genotypes and variants to call.",
        required=True,
        type=str,
    )

    args = parser.parse_args()
    plasmepsin_variants = PlasmepsinVariantCaller(
        args.genotype_files,
        args.output_file,
        args.config,
    )
    plasmepsin_variants.call_plasmepsin_variants()
