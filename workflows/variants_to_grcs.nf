#!/usr/bin/env nextflow

/*
    | VARIANTS_TO_GRCS |-----------------------------------------
    
    This workflow takes a manifest file and and manifest for 
    samples and lanelet VCFs as input. The variant calls in these 
    VCFs are used to determine several key metrics, from which 
    metadata enriched GRCs and barcodes files are assembled. Several
    files are needed for these processes: 
    [1] Chrom key file that the specifies amplicon regions, their genomic 
    coordinates and reference alleles is for genotype file creation. 
    [2] Codon key file for describing the genetic code by linking 
    codons with associated amino acid.
    [3] Kelch reference file which details the codons in the Kelch13
    region - genomic location of each base, base at each position 
    and amino acid.
    [4] DRL information file that describes the amino acid position,
    mutation name, and genomic position for each base in the locus 
    for key drug resistance loci.
    
    A GRC settings file must also be supplied to the pipeline. This 
    file details many important values for GRC creation. These include
    minimum coverage values for Kelch13 mutation calling and species
    calling, Kelch13 regions, Plasmepsin loci genotypes and variants, 
    and amino acid calling / haplotype calling double heterozygous case
    haplotype. It also contains values for a speciation default species 
    and species order, species reference describing the allele for each 
    species at particular loci and barcoding reference information:
    chromosome, locus, reference allele.
    
    The lanelet VCFs specified in the lanelet manifest are used to
    create a genotype file. This genotype file is used throughout
    the workflow, for Kelch13 mutation calling, Plasmepsin copy
    number variation calling, drug resistance haplotype assembly,
    barcode assembly, species calling and complexity of infection 
    estimation. The output from these processes are assembled into 
    2 GRC files, which then have metadata from the manifest added 
    to them.

    2 resulting GRC files and a barcodes file that have had 
    metadata added to them are output.
    ------------------------------------------------------------------
*/

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

        // Those output channels were added to be used by nf-test 
        grc1_no_metadata = grc_assemble.out 
        grc1_with_metadata = add_metadata_and_format.out.grc1
        grc2_with_metadata = add_metadata_and_format.out.grc2
        barcodes = add_metadata_and_format.out.barcodes
    
    
    emit:
        grc1_no_metadata
        grc1_with_metadata
        grc2_with_metadata
        barcodes
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

