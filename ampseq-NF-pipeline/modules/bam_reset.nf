params.bamreset_resetaux = 0
params.bamreset_level = 9
params.bamreset_verbose = 0


process bam_reset {
    /*
    * resets a BAM file to a pre-aligned state
    */
    container ''

    input:
        val(sample_tag)
        path(collated_bam)

    output:
        val("${sample_tag}"), emit: sample_tag
        path("${base_name}.prealigned.bam"), emit: prealigned_bam

    script:
        base_name=collated_bam.baseName
        """
        bamreset \
            resetaux=${params.bamreset_resetaux} \
            level=${params.bamreset_level} \
            verbose=${params.bamreset_verbose} \
            < "${collated_bam}" \
            > "${base_name}.prealigned.bam"

        """
}