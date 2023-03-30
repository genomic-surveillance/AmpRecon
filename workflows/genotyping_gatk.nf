#!/usr/bin/env nextflow

// enable dsl2
nextflow.enable.dsl = 2

include { gatk_haplotype_caller_gatk4 } from '../modules/gatk_haplotype_caller_gatk4.nf'
include { genotype_vcf_at_given_alleles } from '../modules/genotype_vcf_at_given_alleles.nf' addParams(gatk:params.gatk3, bgzip:'bgzip')
include { bqsr } from '../modules/bqsr.nf' addParams(gatk:params.gatk3)
include { upload_pipeline_output_to_s3 } from '../modules/upload_pipeline_output_to_s3.nf'

workflow GENOTYPING_GATK {

  take:
        input_sample_tags_bams_indexes // tuple(sample_tag, bam_file, bam_index_file)
        sample_tag_reference_files_ch // tuple(sample_tag, reference_fasta, snp_list)
  main:

    input_sample_tags_bams_indexes // tuple (sample_tag, bam_file, bam_index)
            | join(sample_tag_reference_files_ch) // tuple (sample_tag, bam_file, bam_index, reference_fasta, snp_list)
            | map{ it -> tuple(it[0], it[1], it[2], it[3])}
            | set{haplotype_caller_input} // tuple(sample_tag, bam_file, bam_index, reference_fasta)

    gatk_haplotype_caller_gatk4(haplotype_caller_input)

    // genotype alleles in VCFs
    gatk_haplotype_caller_gatk4.out.vcf_file_and_index
        | join(sample_tag_reference_files_ch)
        | set{genotyping_input_ch} // tuple (sample_tag, vcf_file, vcf_index, reference_fasta, snp_list)
    
    genotype_vcf_at_given_alleles(genotyping_input_ch).set{genotyped_vcf_ch}

    // upload VCF files / indices to S3 bucket
    if (params.upload_to_s3){
      genotyped_vcf_ch.map{it -> tuple(it[1], it[2])}.flatten().set{output_to_s3}
      upload_pipeline_output_to_s3(output_to_s3)
    }    

  emit:
    genotyped_vcf_ch
}

workflow BQSR {
    take:
        input_sample_tags_bams_indexes
        sample_tag_reference_files_ch // tuple(sample_tag, fasta_file, snp_list)
    
    main:
        // base quality score recalibration
        input_sample_tags_bams_indexes // tuple (sample_tag, bam_file, bam_index)
            | join(sample_tag_reference_files_ch) // tuple (sample_tag, bam_file, bam_index, fasta_file, snp_list)
            | map{ it -> tuple(it[0], it[1], it[2], it[3], it[4])}
            | set{bqsr_input} // tuple(sample_tag, bam_file, bam_index, fasta, snp_list)

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

