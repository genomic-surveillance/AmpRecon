#!/usr/bin/env nextflow

// enable dsl2
nextflow.preview.dsl = 2

// import modules
include { unmap } from '../bespoke_modules/unmap.nf'
include { filter } from '../bespoke_modules/filter.nf'
include { remap } from '../bespoke_modules/remap.nf'

workflow filtering_workflow {
    take:
        bam_ch
    main:
        unmap (bam_ch)
        filter (unmap.out)
        remap (filter.out)
    emit:
        remap.out
}
