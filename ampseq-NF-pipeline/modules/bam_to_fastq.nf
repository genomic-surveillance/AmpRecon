
process bam_to_fastq {
    /*
    * convert BAM files to FASTQ.
    */
    //publishDir "${params.results_dir}/${run_id}", overwrite: true

    input:
        //val(run_id) //needed to know where to publish the files
        val(sample_tag)
        path(bam_file)
        //tuple val(sample_tag), path(clipped_bam)

    output:
        val("${sample_tag}"), emit: sample_tag
        path("${base_name}.fastq"), emit: fastq
        //path("${clipped_bam}"), emit: clipped_bam

    script:
        base_name=bam_file.baseName
        """
        bamtofastq \
            < "${bam_file}" \
            > "${base_name}.fastq"
        """
}
