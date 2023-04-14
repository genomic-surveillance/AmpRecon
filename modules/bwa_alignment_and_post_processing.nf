process bwa_alignment_and_post_processing {
    /*
    * Map reads to reference
    */
    //publishDir "${params.results_dir}", overwrite: true
    label 'alignment_and_post_processing'

    input:
	tuple val(sample_tag), path(fastq), val(reference_fasta), val(panel_name)

    output:
        tuple val(sample_tag), path(bam_file), path("${bam_file}.bai")

    script:
        ref_simplename=file(reference_fasta).simpleName
        bam_file="${sample_tag}-${ref_simplename}.bam"

        """
        bwa mem \
            -p \
            -Y \
            -K 100000000 \
            -t 1 \
            "${reference_fasta}" \
            "${fastq}" |
            scramble -0 -I sam -O bam > ${bam_file}.intermediate

            samtools sort --threads 2 -o ${bam_file}.sorted.bam ${bam_file}.intermediate
            samtools index ${bam_file}.sorted.bam

            rm -rf ${bam_file}.intermediate #look into improving this
            mv ${bam_file}.sorted.bam ${bam_file}
            mv ${bam_file}.sorted.bam.bai ${bam_file}.bai


        """
}


