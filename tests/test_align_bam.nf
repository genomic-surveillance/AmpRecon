#!/usr/bin/env nextflow

include { download_test_fastq_from_s3 } from '../modules/download_test_data.nf'
include { download_idx_from_s3 } from '../modules/download_test_data.nf'
include { download_fasta_from_s3 } from '../modules/download_test_data.nf'
include { align_bam } from '../modules/align_bam.nf'
include { download_test_aligned_sam_from_s3 } from '../modules/download_test_data.nf'
include { test_size } from '../modules/test_tools.nf'
include { test_binary } from '../modules/test_tools.nf'
include { check_md5sum } from '../modules/test_tools.nf'

workflow {

	index = download_idx_from_s3("Pf_GRC1v1.0")
	ref = download_fasta_from_s3("Pf_GRC1v1.0")
	fasta = ref.map { it -> it[0] }
	fastq = download_test_fastq_from_s3("21045_1_ref")
	sample_tag = Channel.of("1")
	panel_name = Channel.of("panel")
	test_ch = create_tuple(index, fastq, fasta)

	align_bam(test_ch)
        remove_header(align_bam.out.sam_file)

        // Header removed from SAM file : random/path/to/ref.fa in header alters md5sum
        sam_file_no_header = remove_header.out
	check_md5sum(sam_file_no_header, "d41d8cd98f00b204e9800998ecf8427e")
}

process remove_header {
    label 'python_plus_samtools'
    input:

    path(sam_file)

    output:
    path({sam_file})

    script:
    """
    samtools view "${sam_file}" > "${sam_file}"
    """
}

process create_tuple {
    stageInMode 'copy'

    input:
    path(index)
    path(fastq)
    path(ref)

    output:
    tuple val("1"), path(fastq), path(ref_file), val("panel_name")

    script:
    ref_file = ref
    """
    echo
    """


}
 

