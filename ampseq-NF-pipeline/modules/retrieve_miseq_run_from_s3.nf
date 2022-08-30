process retrieve_miseq_run_from_s3 {
    /**
    * Downloads and unzips .tar.gz Miseq run from an S3 bucket.
    */
    publishDir "${params.results_dir}", mode: 'move'

    input:
        val(file_id)

    output:
          tuple val("${params.run_id}"), val("${output_path}"), val("${params.lane}"), val("${params.study_name}"), val("${params.read_group}"), val("${params.library}"), emit: tuple_ch
          path("${file_id}")

    script:
        output_path = "${params.results_dir}/${file_id}"
        bucket = params.input_s3_bucket
        """
        s3cmd get s3://"${bucket}"/"${file_id}".tar.gz
        tar -xvzf "${file_id}".tar.gz
        """
}

