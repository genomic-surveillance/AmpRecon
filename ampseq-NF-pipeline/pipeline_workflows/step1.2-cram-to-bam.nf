#!/usr/bin/env nextflow

// enable dsl2
nextflow.enable.dsl = 2

// import modules
include { collate_alignments } from '../modules/collate_alignments.nf'
include { bam_reset } from '../modules/bam_reset.nf'
include { clip_adapters } from '../modules/clip_adapters.nf'
include { bam_to_fastq } from '../modules/bam_to_fastq.nf'
include { align_bam } from '../modules/align_bam.nf'
//include { scramble_sam_to_bam  } from '../modules/scramble_sam_to_bam.nf'
include { mapping_reheader } from '../modules/mapping_reheader.nf'
include { bam_split } from '../modules/bam_split.nf'
include { bam_merge } from '../modules/bam_merge.nf'
include { alignment_filter } from '../modules/alignment_filter.nf'
//include { sort_bam } from '../modules/sort_bam.nf'
include { bam_to_cram } from '../modules/bam_to_cram.nf'

def load_manifest_ch(csv_ch){
  //if csv file is provided as parameter, use it by default and ignore input
  if (!(params.manifest_step1_2 == '')){
      println("Startin from")
      // TODO : add check if file exist
      manifest_fl = params.manifest_step1_2
      csv_ch = Channel.fromPath(manifest_fl)
      }
  // if not set as parameter, assumes is a channel containing a path for the csv
  manifest_ch = csv_ch |
                splitCsv(header:true) |
                map {row-> tuple(row.run_id, row.cram_fl)}

  return manifest_ch
}

workflow cram_to_bam {
    take:
        manifest_fl
        //input_tag
        //input_cram
        //reference_index_files
        //all_manifest_data
    main:
        // Process manifest_ch
        in_ch = load_manifest_ch(manifest_fl)

        // Collate cram files by name
        collate_alignments(in_ch)
        /*
        // Transform BAM file to pre-aligned state
        bam_reset(collate_alignments.out)

        // Remove adapters
        clip_adapters(bam_reset.out)

        // Convert BAM to FASTQ
        bam_to_fastq(clip_adapters.out)

        // Map FASTQ to reference
        bam_to_fastq.out
        .join(all_manifest_data)
        .multiMap {
            tag: it[0]
            fastq: it[1]
            reference_filename: it[3]["reference_fasta"].getName()
        }.set { alignment_input }
        align_bam(alignment_input.tag, alignment_input.fastq, alignment_input.reference_filename, reference_index_files)

        // SAM to BAM
        align_bam.out
        .multiMap {
            tag: it[0]
            sam: it[1]
        }.set { scramble_sam_to_bam_input }
        scramble_sam_to_bam(scramble_sam_to_bam_input.tag, scramble_sam_to_bam_input.sam)

        // Merges the current headers with the old ones. Keeping @SQ.*\tSN:([^\t]+) matching lines from the new header.
        scramble_sam_to_bam.out
        .join(scramble_sam_to_bam.out)
        .join(all_manifest_data)
        .multiMap {
            tag: it[0]
            clipped: it[2]
            bam: it[3]
            reference_filename: it[4]["reference_fasta"].getName()
        }.set { mapping_reheader_input }
        mapping_reheader(mapping_reheader_input.tag, mapping_reheader_input.clipped, mapping_reheader_input.bam, mapping_reheader_input.reference_file, reference_index_files)

        // Split BAM rank pairs to single ranks per read
        mapping_reheader.out
        .join(bam_to_fastq.out)
        .multiMap {
            tag: it[0]
            reheadered_bam: it[1]
            clipped: it[3]
        }.set { bam_split_input }

        bam_split(bam_split_input.tag, bam_split_input.reheadered_bam, bam_split_input.clipped)

        // Merge BAM files with same reads
        bam_merge(bam_split.out, bam_split_input.clipped)

        // Split alignments into different files
        bam_merge.out
        .multiMap {
            tag: it[0]
            bam: it[1]
        }.set { alignment_filter_input }
        alignment_filter(alignment_filter_input.tag, alignment_filter_input.bam)

        // BAM sort by coordinate
        alignment_filter.out
        .multiMap {
            tag: it[0]
            alignment_file: it[1]
        }.set { bam_sort_input }
        sort_bam(bam_sort_input.tag, bam_sort_input.alignment_file)
        bam_ch = sort_bam.out

    emit:
        bam_ch
*/
}
