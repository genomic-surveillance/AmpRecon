#!/usr/bin/env nextflow

// enable dsl2
nextflow.enable.dsl = 2

// import subworkflows
include { DESIGNATE_PANEL_RESOURCES } from './designate_panel_resources.nf'
include { PULL_FROM_IRODS } from './pipeline-subworkflows/pull_from_irods.nf'


workflow IRODS {
    take:
        irods_manifest // irods manifest file
        reference_ch // tuple (fasta, panel_name, snp_list)
    main:
        // load manifest content
        irods_ch =  Channel.fromPath(irods_manifest, checkIfExists: true)
                      | splitCsv(header: true, sep: '\t')
                      //| map { row -> tuple(row.id_run, row.primer_panel, row.WG_lane) }
                      | map { row ->
                              WG_lane = "${row.irods_path}".split('/')[-1].split('\\.')[0]
                              tuple(row.sample_id, row.primer_panel, WG_lane, row.irods_path) 
                            }
                      | map { it -> tuple("${it[2]}_${it[0]}_${it[1]}", it[1], it[3])} // tuple (WG_lane_sample_id_panel_name, panel_name, irods_path)

        // assign each sample tag the appropriate set of reference files
        irods_ch.map{it -> tuple(it[0], it[1])}.set{new_sample_tag_panel_ch} // tuple (new_sample_id, panel_name)
        DESIGNATE_PANEL_RESOURCES(new_sample_tag_panel_ch, reference_ch)
        sample_tag_reference_files_ch = DESIGNATE_PANEL_RESOURCES.out.sample_tag_reference_files_ch
        // tuple (new_sample_id, panel_name, path/to/reference/genome, snp_list)

        // run step1.2b - pull from iRODS
        PULL_FROM_IRODS(irods_ch.map{it -> tuple(it[0], it[2])}) // tuple (new_sample_id, irods_path)
        bam_files_ch = PULL_FROM_IRODS.out.bam_files_ch

    emit:
        bam_files_ch
        sample_tag_reference_files_ch // tuple (new_sample_id, panel_name, path/to/reference/genome, snp_list)
}

