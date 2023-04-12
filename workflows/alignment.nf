#!/usr/bin/env nextflow

// enable dsl2
nextflow.enable.dsl = 2

include { bam_reset } from '../modules/bam_reset.nf'
include { bam_to_fastq } from '../modules/bam_to_fastq.nf'
include { bwa_alignment } from '../modules/bwa_alignment.nf'
include { scramble_sam_to_bam } from '../modules/scramble.nf'
include { add_read_group } from '../modules/add_read_group.nf'
include { samtools_sort } from '../modules/samtools.nf'
include { samtools_index } from '../modules/samtools.nf'
include { upload_pipeline_output_to_s3 } from '../modules/upload_pipeline_output_to_s3.nf'

workflow ALIGNMENT {
  take:
    fastq_ch

  main:
     // do new alignment
    bwa_alignment(fastq_ch)


    // convert sam to bam
    scramble_sam_to_bam(bwa_alignment.out.sample_tag, bwa_alignment.out.sam_file)

    scramble_sam_to_bam.out
		       .set{ scramble_out_ch }
     
    // sort and index bam
    samtools_sort(scramble_out_ch)
    samtools_index(samtools_sort.out)

    // upload BAM files and index files to S3 bucket
    if (params.upload_to_s3){
      output_to_s3 = samtools_index.out.map{it -> tuple(it[1], it[2])}.flatten()
      upload_pipeline_output_to_s3(output_to_s3)
    }

  emit:
    samtools_index.out
}
