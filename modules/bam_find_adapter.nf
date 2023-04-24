process bam_find_adapter {
    /*
    * Searches for sequencing adapter contamination with a BAM  file.
    */
    publishDir "${params.results_dir}/", overwrite: true, mode: "copy"
    label 'biobambam2'
    input:
        path(bam_file)

    output:
        path("${adapters_bam_file}")

    script:
        adapters_bam_file = "${bam_file}.adapters"
        """
        bamadapterfind level=9 < ${bam_file} > ${adapters_bam_file}
        """

}

