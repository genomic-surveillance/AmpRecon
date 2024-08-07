#!/usr/bin/env nextflow
// Copyright (C) 2023 Genome Surveillance Unit/Genome Research Ltd.


/*
    | SANGER_IRODS_TO_READS |-----------------------------------------
    
    This workflow downloads CRAM files from iRODS and does a series
    of file conversions to produce an adapter trimmed fastq file. 

    Here, a tab-separated iRODS manifest is supplied containing
    iRODS paths. The workflow will then retrieve the relevant 
    CRAM files, convert to BAM formatted files, strip adapter
    sequences and convert the BAM to fastq format in preparation
    for alignment and SNP calling.
    ------------------------------------------------------------------
*/

// enable dsl2
nextflow.enable.dsl = 2

// import irods processes

include { bam_to_fastq } from '../modules/bam_to_fastq.nf'
include { clip_adapters } from '../modules/clip_adapters.nf'
include { irods_retrieve } from '../modules/irods_retrieve.nf'
include { scramble_cram_to_bam } from '../modules/scramble.nf'
include { validate_irods_mnf } from '../modules/validate_irods_mnf.nf'
// -------------------------------------------------------------------------

workflow SANGER_IRODS_TO_READS {
    take:
        irods_manifest // irods manifest file
        reference_ch // tuple (fasta, panel_name, snp_list)
    main:
        // load manifest content
        irods_ch =  irods_manifest
                    | splitCsv(header: true, sep: '\t')
                    | map { row ->
                        WG_lane = "${row.irods_path}".split('/')[-1].split('\\.')[0]
                        tuple(row.sample_id, row.primer_panel, WG_lane, row.irods_path) 
                    }
                    | map { it -> tuple("${it[2]}_${it[0]}_${it[1]}", it[1], it[3], it[0])} // tuple (WG_lane_sample_id_panel_name, panel_name, irods_path, sample_id)

        // link file_id to sample_id
        irods_ch.map{it -> tuple(it[0], it[3])}.set{file_id_to_sample_id_ch}

        // assign each sample tag the appropriate set of reference files
        irods_ch.map{it -> tuple(it[0], it[1])}.set{new_file_id_panel_ch} // tuple (file_id, panel_name)

        new_file_id_panel_ch
          | combine(reference_ch,  by: 1) // tuple (panel_name, file_id, fasta,snp_list)
          | map{it -> tuple(it[1], it[0], it[2], it[3])}
          | set{file_id_reference_files_ch} // tuple (file_id, panel_name, path/to/reference/genome, snp_list)

        // Retrieve CRAM files from iRODS
        irods_paths = irods_ch.map{it -> tuple(it[0], it[2])} // tuple (file_id, irods_path)
        irods_retrieve(irods_paths)

        // Convert iRODS CRAM files to BAM format
        scramble_cram_to_bam(irods_retrieve.out)

        // Remove marked adapter sequences
        clip_adapters(scramble_cram_to_bam.out)

        // Convert to Fastq
        bam_to_fastq(clip_adapters.out)

        bam_to_fastq.out
                | join(file_id_reference_files_ch)
                | map { it -> [ it[0], it[1], it[3] ] }
                | set { fastq_ch }

    emit:
        fastq_ch // tuple (file_id, fastq_ch, path/to/reference/genome)
        file_id_reference_files_ch // tuple (file_id, panel_name, path/to/reference/genome, snp_list)
        file_id_to_sample_id_ch // tuple (file_id, sample_id)
}

def irods_to_reads_parameter_check(){

    /*
    This functions counts the number of errors on input parameters exclusively used on IRODS subworkflow
    
    checks:
     - if irods manifest was provided
     - if irods manifest provided exists
    
    False for any of those conditions counts as an error.
    
    Returns
    ---
    <int> the number of errors found
    */

    def error = 0
    if (params.irods_manifest == null){
        log.error("An irods_manifest parameter must be provided for execution mode '${params.execution_mode}'.")
        error += 1
    }

    if (params.irods_manifest){
        irods_manifest = file(params.irods_manifest)
        if (!irods_manifest.exists()){
            log.error("The irods manifest file specified (${params.irods_manifest}) does not exist.")
            error += 1
        }
        else {
            validate_irods_mnf(params.irods_manifest, params.panels_settings)
        }
    }

    if (error > 0) {
        log.error("Parameter errors were found, the pipeline will not run")
        exit 1
    }
}

workflow {
    // File required for Sanger iRODS to Reads input channels
    channel_data = Channel.fromPath(params.channel_data_file, checkIfExists: true)
        .splitCsv(header: true, sep: '\t')

    irods_to_reads_parameter_check()
    // Sanger iRODS to Reads input channels
    irods_manifest = Channel.fromPath(params.irods_manifest)
    reference_ch = channel_data.map { row -> tuple(row.reference_file, row.panel_name, row.snp_list) }

    // Run Sanger iRODS to Reads workflow
    SANGER_IRODS_TO_READS(irods_manifest, reference_ch)
}