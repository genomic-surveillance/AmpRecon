#!/usr/bin/env nextflow

// enable dsl2
nextflow.enable.dsl = 2

// import subworkflows
include { REALIGNMENT } from './pipeline-subworkflows/realignment.nf'
include { GENOTYPING_GATK } from './pipeline-subworkflows/genotyping_gatk.nf'
include { GENOTYPING_BCFTOOLS } from './pipeline-subworkflows/genotyping_bcftools.nf'

include { bqsr } from '../modules/bqsr.nf' addParams(gatk:params.gatk3)
include { samtools_index } from '../modules/samtools.nf'
/*
Here all workflows which are used regardless of the entry point (iRODS or inCountry)
are setup
*/

workflow COMMON {

    take:
        bam_files_ch // tuple(sample_id, bam_file)
        sample_tag_reference_files_ch // tupl (sample_id, panel_name, reference_fasta_file, snp_list)
        annotations_ch // tuple (panel_name, anotation_file)
    main:
        // mapping tuple to multichannel 
        if (params.aligned_bams_mnf == null){
            bam_files_ch
              | multiMap {
                sample_tag: it[0]
                bam_file: it[1]
                }
              | set { realignment_In_ch }
        
        // do realignment and read counts
        sample_tag_reference_files_ch.map{it -> tuple(it[0], it[2], it[1])}.set{realignment_ref_ch} // tuple (sample_id, fasta_file, panel_name)
        REALIGNMENT(
                    realignment_In_ch.sample_tag,
                    realignment_In_ch.bam_file,
                    realignment_ref_ch,
                    annotations_ch
                )

        genotyping_In_ch = REALIGNMENT.out
        }

        if (params.execution_mode == "aligned_bams"){
        genotyping_In_ch = bam_files_ch
        }
        // genotyping
        sample_tag_reference_files_ch.map{it -> tuple(it[0], it[2])}.set{bqsr_ref_ch} // tuple (sample_id, fasta_file)
        BQSR(
            genotyping_In_ch,
            bqsr_ref_ch
        )

        // genotyping
        if( params.genotyping_gatk == true ) {
        sample_tag_reference_files_ch.map{it -> tuple(it[0], it[2], it[3])}.set{gatk_genotyping_ref_ch} // tuple (sample_id, fasta_file, snp_list)
                GENOTYPING_GATK(
                   BQSR.out,
                   gatk_genotyping_ref_ch
                )
        }

        if( params.genotyping_bcftools == true ) {
        sample_tag_reference_files_ch.map{it -> tuple(it[0], it[2], it[3])}.set{bcftools_genotyping_ref_ch} // tuple (sample_id, fasta_file, snp_list)
                GENOTYPING_BCFTOOLS(
                   BQSR.out,
                   bcftools_genotyping_ref_ch
                )
        }
}

workflow BQSR {
    take:
        input_sample_tags_bams_indexes
        sample_tag_reference_files_ch // tuple(sample_tag, fasta_file)
    
    main:
        // base quality score recalibration
        input_sample_tags_bams_indexes // tuple (sample_tag, bam_file, bam_index)
            | join(sample_tag_reference_files_ch) // tuple (sample_tag, bam_file, bam_index, fasta_file)
            | map{ it -> tuple(it[0], it[1], it[2], it[3])}
            | set{bqsr_input} // tuple(sample_tag, bam_file, bam_index, fasta)

        if (!params.skip_bqsr) {
            bqsr(bqsr_input)
            samtools_index(bqsr.out)
            
            // haplotype caller
            post_bqsr_output = samtools_index.out
        }
        else {
            post_bqsr_output = input_sample_tags_bams_indexes
        }
    emit:
        post_bqsr_output
}
