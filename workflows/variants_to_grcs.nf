#!/usr/bin/env nextflow

// enable dsl2
nextflow.enable.dsl = 2

// import modules
include { assemble_genotype_file } from '../grc_tools/genotype_file_creation/assemble_genotype_file.nf'
include { grc_kelch13_mutation_caller } from '../grc_tools/kelch13/grc_kelch13_mutation_caller.nf'
include { grc_plasmepsin_cnv_caller } from '../grc_tools/plasmepsin/grc_plasmepsin_cnv_caller.nf'
include { grc_speciate } from '../grc_tools/speciation/grc_speciate.nf'
include { grc_barcoding } from '../grc_tools/barcode/grc_barcoding.nf'
include { grc_estimate_coi } from '../grc_tools/COI/grc_estimate_coi.nf'
include { grc_amino_acid_caller } from '../grc_tools/amino_acid_calling/grc_amino_acid_caller.nf'
include { grc_assemble } from '../grc_tools/assemble_grc1/grc_assemble.nf'
include { add_metadata_and_format } from '../grc_tools/metadata/add_metadata_and_format.nf'

workflow VARIANTS_TO_GRCS {
    take:
        manifest_file
        lanelet_manifest_file
        chrom_key_file
        kelch_reference_file
        codon_key_file
        drl_information_file

    main:
        // Write genotype file
        assemble_genotype_file(lanelet_manifest_file, chrom_key_file)
        genotype_files_ch = assemble_genotype_file.out

        // Call mutations at Kelch13 loci
        grc_kelch13_mutation_caller(genotype_files_ch, kelch_reference_file, codon_key_file)

        // Call copy number variation at Plasmepsin breakpoint
        grc_plasmepsin_cnv_caller(genotype_files_ch)
        
        // Create barcodes
        grc_barcoding(genotype_files_ch)

        // Determine species
        grc_speciate(genotype_files_ch, grc_barcoding.out.barcoding_file)
        if (params.DEBUG_no_coi == false){
            // Complexity of infection estimation
            grc_estimate_coi(grc_barcoding.out.barcoding_file)
            coi_grc_ch = grc_estimate_coi.out
        }

        if (params.DEBUG_no_coi == true){
            coi_grc_ch = Channel.empty()
        }
        // Assemble drug resistance haplotypes and GRC2
        grc_amino_acid_caller(genotype_files_ch, drl_information_file, codon_key_file)

        // Assemble GRC1
        grc_kelch13_mutation_caller.out
            .concat(grc_plasmepsin_cnv_caller.out)
            .concat(grc_barcoding.out.barcoding_file)
            .concat(grc_speciate.out)
            .concat(coi_grc_ch)
            .concat(grc_amino_acid_caller.out.drl_haplotypes)
            .collect()
            .set{grc1_components}
        grc_assemble(grc1_components)

        // Format and add metadata to GRCs and barcodes files
        add_metadata_and_format(manifest_file, grc_assemble.out, grc_amino_acid_caller.out.grc2, grc_barcoding.out.barcoding_split_out_file)

}

workflow {
    // Files required for GRC creation
    Channel.fromPath(params.grc_settings_file_path, checkIfExists: true)
    manifest_file = Channel.fromPath(params.manifest_path, checkIfExists: true)
    lanelet_manifest_file = Channel.fromPath(params.lanelet_manifest_path, checkIfExists: true)
    chrom_key_file = Channel.fromPath(params.chrom_key_file_path, checkIfExists: true)
    kelch_reference_file = Channel.fromPath(params.kelch_reference_file_path, checkIfExists: true)
    codon_key_file = Channel.fromPath(params.codon_key_file_path, checkIfExists: true)
    drl_information_file = Channel.fromPath(params.drl_information_file_path, checkIfExists: true)

    // Run GRC creation workflow
    VARIANTS_TO_GRCS(manifest_file, lanelet_manifest_file, chrom_key_file, kelch_reference_file, codon_key_file, drl_information_file)
}
