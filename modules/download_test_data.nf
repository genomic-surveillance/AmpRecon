#!/usr/bin/env nextflow

nextflow.enable.dsl = 2


process download_bcl_from_s3 {
	//download and unzip bcl related files for testing purposes

	input:
	val(bcl_id)

	output:
	path("${bcl_id}")

	script:
	"""
	curl https://amplicon-test-data.cog.sanger.ac.uk/${bcl_id}.tar.gz > ${bcl_id}.tar.gz
	tar -xvzf ${bcl_id}.tar.gz
	"""
}


process download_i2b_output_from_s3 {

	//download reference .bam generated by bambi i2b

	input:
	val(bcl_id)

	output:
	path("*.bam")
	
	script:
	"""
	curl https://amplicon-test-data.cog.sanger.ac.uk/${bcl_id}.test_i2b.subset.bam > ${bcl_id}.test.bam
	"""
}


process download_bambi_decode_output_from_s3 {
	
	//download bambi decode test data from s3 

	input:
	val(bcl_id) 

	output:
	tuple path("*.bam"), path("*.metrics")

	script:
	"""
	curl https://amplicon-test-data.cog.sanger.ac.uk/${bcl_id}_bambi_decode.subset.bam > test.decode.bam
	curl https://amplicon-test-data.cog.sanger.ac.uk/${bcl_id}.subset.metrics > test.decode.metrics
	"""

}


process download_bamadapterfind_output_from_s3 {


	input:
	val(bcl_id)

	output:
	path("*.bam"), emit: test_bam
	path("*.metrics"), emit: metrics

	script:
	"""
	curl https://amplicon-test-data.cog.sanger.ac.uk/${bcl_id}.adapters.test.bam > test.adapters.bam
	curl https://amplicon-test-data.cog.sanger.ac.uk/${bcl_id}.subset.metrics > test.metrics
	"""

}


process download_test_cram_from_s3 {


	input:
	val(file_id)

	output:
	path("*.cram")

	script:
	"""
	curl https://amplicon-test-data.cog.sanger.ac.uk/${file_id}.cram > test.cram
	"""


}

process download_test_collated_bam_from_s3 {


        input:
        val(file_id)

        output:
        path("*.bam")

        script:
        """
        curl https://amplicon-test-data.cog.sanger.ac.uk/${file_id}.collated.bam > reference_test.collated.bam
        """


}

process download_test_reset_bam_from_s3 {


        input:
        val(file_id)

        output:
        path("*.bam")

        script:
        """
        curl https://amplicon-test-data.cog.sanger.ac.uk/${file_id}.reset.bam > test.reset.bam
        """


}

process download_test_clipped_bam_from_s3 {


        input:
        val(file_id)

        output:
        path("*.bam")

        script:
        """
        curl https://amplicon-test-data.cog.sanger.ac.uk/${file_id}.clipped.bam > test.clipped.bam
        """


}

process download_test_fastq_from_s3 {


        input:
        val(file_id)

        output:
        path("*.fastq")

        script:
        """
        curl https://amplicon-test-data.cog.sanger.ac.uk/${file_id}.fastq > test.fastq
        """


}

process download_test_aligned_sam_from_s3 {


        input:
        val(file_id)

        output:
        path("*.sam")

        script:
        """
        curl https://amplicon-test-data.cog.sanger.ac.uk/${file_id}.sam > test.aligned.sam
        """

}

process download_fasta_from_s3{

	input:
	val(file_id)

	output:
	tuple path("test.fa"), path("test.dict")

	script:
	"""
	curl https://amplicon-test-data.cog.sanger.ac.uk/pf_grc1v1.0/${file_id}.fasta > test.fa
	curl https://amplicon-test-data.cog.sanger.ac.uk/pf_grc1v1.0/${file_id}.dict > test.dict
	"""


}

process download_idx_from_s3 {


	input:
	val(file_id)

	output:
	path("test*")

	script:
	"""
	curl https://amplicon-test-data.cog.sanger.ac.uk/pf_grc1v1.0/${file_id}.fai > test.fai
	curl https://amplicon-test-data.cog.sanger.ac.uk/pf_grc1v1.0/${file_id}.dict > test.dict
	curl https://amplicon-test-data.cog.sanger.ac.uk/pf_grc1v1.0/${file_id}.fasta.sa > test.fa.sa
	curl https://amplicon-test-data.cog.sanger.ac.uk/pf_grc1v1.0/${file_id}.fasta.amb > test.fa.amb
	curl https://amplicon-test-data.cog.sanger.ac.uk/pf_grc1v1.0/${file_id}.fasta.bwt > test.fa.bwt
	curl https://amplicon-test-data.cog.sanger.ac.uk/pf_grc1v1.0/${file_id}.fasta.ann > test.fa.ann
	curl https://amplicon-test-data.cog.sanger.ac.uk/pf_grc1v1.0/${file_id}.fasta.pac > test.fa.pac
	"""
}


process download_test_scrambled_bam_from_s3 {

	input:
	val(file_id)

	output:
	path("*.staden.scrambled.bam")

	script:
	"""
	curl https://amplicon-test-data.cog.sanger.ac.uk/${file_id}.selected.bam > reference.staden.scrambled.bam
	"""
}

process download_test_reheadered_bam_from_s3 {

	input:
	val(file_id)

	output:
	path("*reheader_ref.bam")

	script:
	"""
	curl https://amplicon-test-data.cog.sanger.ac.uk/${file_id}.reheader_ref.bam > reference.reheader_ref.bam
	"""
}

process download_test_split_bam_from_s3 {

	input:
	val(file_id)

	output:
	path("*.split.bam")

	script:
	"""
	curl https://amplicon-test-data.cog.sanger.ac.uk/${file_id}.split.bam > reference.split.bam
	"""
}

