// Copyright (C) 2023 Genome Surveillance Unit/Genome Research Ltd.

params.grc_name = params.batch_id + "_GRC.txt"

process grc_add_metadata {
    publishDir "${params.results_dir}/grc/", overwrite: true, mode: "copy"

    label "grc_tools"
    input:
        path(manifest_file)
        path(grc_file)

    output:
        path("${output_grc}"), emit: grc

    script:
        output_grc = params.grc_name

        """
        grc_metadata.py \
            --manifest_file ${manifest_file} \
            --grc ${grc_file} \
            --output_file_grc "${output_grc}"
        """
}
