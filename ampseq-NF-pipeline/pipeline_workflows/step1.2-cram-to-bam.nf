#!/usr/bin/env nextflow

// enable dsl2
nextflow.enable.dsl = 2

// import modules
include { collate_alignments } from '../modules/collate_alignments.nf'
include { bam_reset } from '../modules/bam_reset.nf'
include { clip_adapters } from '../modules/clip_adapters.nf'
include { bam_to_fastq } from '../modules/bam_to_fastq.nf'
include { align_bam } from '../modules/align_bam.nf'
include { scramble_sam_to_bam } from '../modules/scramble.nf'
include { bambi_select } from '../modules/scramble_sam_to_bam.nf'
include { mapping_reheader } from '../modules/mapping_reheader.nf'
include { bam_split } from '../modules/bam_split.nf'
include { bam_merge } from '../modules/bam_merge.nf'
include { alignment_filter } from '../modules/alignment_filter.nf'
include { sort_bam } from '../modules/sort_bam.nf'
include { bam_to_cram } from '../modules/bam_to_cram.nf'
include { scramble_cram_to_bam } from '../modules/scramble.nf'
include { irods_manifest_parser } from '../modules/irods_manifest_parser.nf'
include { irods_retrieve } from '../modules/irods_retrieve.nf'


def load_manifest_ch(csv_ch){
  //if csv file is provided as parameter, use it by default and ignore input
  if (!(params.manifest_step1_2 == '')){
      // TODO : add check if file exist
      manifest_fl = params.manifest_step1_2
      csv_ch = Channel.fromPath(manifest_fl)
      }
  // if not set as parameter, assumes is a channel containing a path for the csv
  manifest_ch = csv_ch |
                splitCsv(header:true) |
                multiMap {row -> run_id:row.run_id
                                 cram_fl:row.cram_fl
                                 sample_tag:row.sample_tag}
  return manifest_ch
}

process writeOutputManifest {

  //publishDir "${params.results_dir}/${run_id}", mode: 'copy', overwrite: true

  input:
    tuple val(sample_tag), path(bam_file)
    val(run_id)
    // TODO create a python box container

  //output:
  //  tuple val(run_id), path("${run_id}_out1.2_mnf.csv")
// The $/ ... /$ is necessary to avoid nextflow to read "\n" incorrectly
$/
#!/usr/bin/python3
from pathlib import Path

# setup inputs
run_id = "${run_id}"
bam_fl = "${bam_file}"
sample_tag = "${sample_tag}"
publishDir = f"${params.results_dir}/{run_id}/"
bam_dir=f"${params.results_dir}{run_id}/"

# if manifest already exists, just append new lines
path_to_mnf = f"{publishDir}/{run_id}_out1.2_mnf.csv"
if Path(path_to_mnf).is_file():
    out_mnf = open(f"{path_to_mnf}", "a")

# if manifest does not exist, create file and write header
else:
    out_mnf = open(f"{path_to_mnf}", "w")
    out_mnf.write("run_id,bam_fl,sample_tag\n")

# write manifest line for the bam file
out_mnf.write(f"{run_id},{bam_dir}{bam_fl},{sample_tag}\n")
out_mnf.close()
/$
}

workflow cram_to_bam {
    take:
        // manifest from step 1.1
        manifest_fl
        // reference index files
        ref_bwa_index_fls
        ref_fasta_index_fl
        ref_dict_fl
        //irods channel
        irods_ch
    main:
        // Process manifest
        mnf_ch = load_manifest_ch(manifest_fl)

        // Collate cram files by name
        collate_alignments(mnf_ch.run_id, mnf_ch.cram_fl, mnf_ch.sample_tag)

        // Transform BAM file to pre-aligned state

        bam_reset(collate_alignments.out.sample_tag,
                  collate_alignments.out.collated_bam)
        bamReset_Out_ch = bam_reset.out
        // Remove adapters
        clip_adapters(bam_reset.out.sample_tag, bam_reset.out.prealigned_bam)

        // Convert BAM to FASTQ
        bam_to_fastq(clip_adapters.out)

        align_bam(bam_to_fastq.out.sample_tag,
                  bam_to_fastq.out.fastq,
                  params.reference_fasta,
                  ref_bwa_index_fls)

        // SAM to BAM
        // scramble sam to bam (?)
        //bambi_select(align_bam.out.sample_tag, align_bam.out.sam_file)
        scramble_sam_to_bam(align_bam.out.sample_tag, align_bam.out.sam_file)

        // Merges the current headers with the old ones.
        // Keeping @SQ.*\tSN:([^\t]+) matching lines from the new header.
        reheader_in_ch = scramble_sam_to_bam.out.join(clip_adapters.out)

        mapping_reheader(reheader_in_ch, params.reference_fasta, ref_dict_fl)

        // Split BAM rank pairs to single ranks per read
        bam_split(mapping_reheader.out)

        // Merge BAM files with same reads
        bam_merge_In_ch = mapping_reheader.out.join(bam_split.out)
        //bam_merge_In_ch.view()

        bam_merge(bam_merge_In_ch)

        // Split alignments into different files
        alignment_filter(bam_merge.out.sample_tag,
                         bam_merge.out.merged_bam)

        // BAM sort by coordinate

        sort_bam(alignment_filter.out.sample_tag,
                 alignment_filter.out.selected_bam)
        bam_ch = sort_bam.out

        // --- IRODS ----------------------------------------------------------
        // Parse iRODS manifest file
        irods_manifest_parser(irods_ch)

        // Retrieve CRAM files from iRODS
        irods_retrieve(irods_manifest_parser.out)

        // Convert iRODS CRAM files to BAM format
        scramble_cram_to_bam(irods_retrieve.out,
                             params.reference_fasta,
                             ref_fasta_index_fl)

        // Concatenate in-country BAM channel with iRODS BAM channel
        bam_ch.concat(scramble_cram_to_bam.out).set{ bam_files_ch }

        // --------------------------------------------------------------------
        // write manifest out
        writeOutputManifest(bam_files_ch, mnf_ch.run_id)

    emit:
        bam_ch

}
/*
// -------------------------- DOCUMENTATION -----------------------------------
[1] Read pairs within each CRAM file are first collated and output in BAM format.
[2] Collated BAM files are reset to their prealigned state by removing all @SQ from header, all reads marked as unmapped,
dropping non-primary alignments and sorting order to set to unknown.
[4] Previously identified adapter sequences in each BAM are then clipped off and moved into auxiliary fields.
[5] BAM files are converted to FASTQ format, before being aligned to a reference genome.
[6] The mapped SAM files are scrambled / converted into BAM files.
[7] Specific headers from the adapters clipped BAM file are copied to the scrambled, realigned BAM files.
Duplicate IDs for @RG and @PG records in the header are made unique with the addition of a suffix, read records are also updated.
[8] Rank pairs produced by the collation are converted into single ranks per read.
[9] BAM files with the same reads are merged. Ranks are also stripped from the alignments, clipped sequences are reinserted and quality string parts added.
[10] Reads from all of the BAM files are split into separate files depending on their alignments.
[11] Alignments in the BAM files are sorted by coordinate. The sorted BAM files are emitted ready for further processing.

*/