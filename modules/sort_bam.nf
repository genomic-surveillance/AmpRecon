params.bamsort = 'bamsort'
params.bamsort_threads = 24
params.bamsort_sort_order = 'coordinate'
params.bamsort_level = 0
params.bamsort_fixmate = 1
params.bamsort_add_markup_support = 1


process sort_bam {

    //publishDir "${params.results_dir}", overwrite: true
    label 'biobambam2'

    input:
        val(run_id)
        val(tag)
        path(input_file) // e.g. bam

    output:
        tuple val(tag), path("${output_file}"), val(run_id)

    script:
        bamsort=params.bamsort
        base_name=input_file.getSimpleName()
        tmp_file="${base_name}.tmp"
        output_file="${base_name}.sorted.bam"

        """
        ${bamsort} \
            threads=${params.bamsort_threads} \
            SO=${params.bamsort_sort_order}   \
            level=${params.bamsort_level}     \
            fixmate=${params.bamsort_fixmate} \
            addupmarksupport=${params.bamsort_add_markup_support} \
            tmpfile="${tmp_file}" \
            < "${input_file}" \
            > "${output_file}"

        """
}