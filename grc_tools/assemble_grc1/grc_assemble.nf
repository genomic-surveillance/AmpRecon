params.grc_1_name = "GRC1.intermediate.tsv"

process grc_assemble {
    label "grc_tools"
    input:
        path(grc_components_list)

    output:
        path("${output_grc_1}")

    script:
        output_grc_1 = params.grc_1_name
        grc_component_files = grc_components_list.join(" ")
        """
        grc_assemble.py -grcs_in ${grc_component_files} -grc_out_name ${output_grc_1}
        """
}
