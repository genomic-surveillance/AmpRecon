params.bwa='bwa'
params.bwa_num_threads = 24
params.bwa_batch_input_bases = 100000000

process align_bam {
    /*
    * Map reads to reference
    */
    //publishDir "${params.results_dir}", overwrite: true
    label 'bwa'

    input:
        tuple val(sample_tag), path(fastq), path(reference_fasta), path(ref_bwa_index_fls), val(pannel_name)

    output:
        // WARNING: this process adds the reference to the sample_tag, if this output is gonna be use 
        //          for join channels, take this into account.
        val("${sample_tag}-${ref_simplename}"), emit: sample_tag
        path("${sample_tag}-${ref_simplename}.sam"), emit: sam_file

    script:
        bwa=params.bwa
        ref_simplename=reference_fasta.simpleName
        """
        bwa mem \
            -p \
            -Y \
            -K ${params.bwa_batch_input_bases} \
            -t ${params.bwa_num_threads} \
            "${reference_fasta}" \
            "${fastq}" \
            > "${sample_tag}-${ref_simplename}.sam"
        """
}
// --- | WARNING | ------------------------------------------------------------
// currently no .alt is used, this means that reads that can map multiply are
// given low or zero MAPQ scores.
// the lack of this files is equivalent to add the -j option to the command
// disables the alt-handling.

// TODO: decide if alt file should be added or not
// ----------------------------------------------------------------------------

/*
  --- | DOCUMENTATION | -------------------------------------------------------
 https://manpages.ubuntu.com/manpages/bionic/man1/bwa.1.html
 we use -p to signal this is an interleaved paired-end fastq
 we use -Y to signal soft-clipping CIGAR operation for supplementary alignments

 Information regarding soft-clpping and what CIGAR string is, look here
 https://sites.google.com/site/bioinformaticsremarks/bioinfo/sam-bam-format/what-is-a-cigar
  ------------------------------------------------------------------------------
*/

