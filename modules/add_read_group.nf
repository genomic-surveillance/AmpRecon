process add_read_group {
    /*
    * Adds a read group from a BAM header to another BAM header
    */
    input:
        tuple val(sample_tag), path(remapped_bam_file), path(bam_file)

    output:
        tuple val(sample_tag), path("${new_bam_file}")

    script:
        simple_name = remapped_bam_file.baseName
        new_bam_file = "${simple_name}.bam"
        temp_bam_name = "temp.${simple_name}.bam"
        """
        # Change remapped bam file name so that its not same as output name
        mv ${remapped_bam_file} ${temp_bam_name}

        samtools view -H ${bam_file} | grep '^@RG' | head -1 >> ${bam_file}.header.sam.tmp

        # Fix sample name in header
        cat ${bam_file}.header.sam.tmp | \
        sed "s/\\tSM:[^[:space:]]*\\t/\\tSM:${sample_tag}\\t/" | \
        sed "s/\\tLB:[^[:space:]]*\\t/\\tLB:${sample_tag}\\t/" \
        > ${bam_file}.header.sam

        # Replace header
        samtools addreplacerg -r "\$(< ${bam_file}.header.sam)" -o ${new_bam_file} --threads 8 ${temp_bam_name}
        """
}
