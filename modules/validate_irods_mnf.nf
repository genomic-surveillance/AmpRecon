#!/usr/bin/env nextflow

nextflow.enable.dsl=2

process validate_irods_mnf {

    input:
        path(irods_mnf_file)
        path(panel_settings_file)

    script:
    """
    validate_irods_fastq_mnf.py ${irods_mnf_file} ${panel_settings_file} irods
    """
}
