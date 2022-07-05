#!/bin/bash


set -e


nextflow run tests/test_bamadapter_find.nf -c tests/test_bamadapter_find.config -profile standard 
wait
nextflow run tests/test_samtools_bam2cram.nf -c tests/test_samtools_bam2cram.config -profile standard   