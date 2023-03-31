#!/usr/bin/env nextflow

// enable dsl2
nextflow.enable.dsl = 2

// --- import modules ---------------------------------------------------------
// - workflows

include { PARSE_PANEL_SETTINGS } from './workflows/parse_panels_settings.nf'
include { SANGER_IRODS_TO_READS; count_irods_to_reads_params_errors} from './workflows/sanger_irods_to_reads.nf'
include { MISEQ_TO_READS; count_miseq_to_reads_params_errors } from './workflows/miseq_to_reads.nf'
include { READS_TO_VARIANTS } from './workflows/reads_to_variants.nf'
include { VARIANTS_TO_GRCS } from './workflows/variants_to_grcs.nf'
include { validate_parameters } from './workflows/input_handling.nf'
// logging info ----------------------------------------------------------------
// This part of the code is based on the FASTQC PIPELINE (https://github.com/angelovangel/nxf-fastqc/blob/master/main.nf)

/*
* ANSI escape codes to color output messages, get date to use in results folder name
*/
ANSI_GREEN = "\033[1;32m"
ANSI_RED = "\033[1;31m"
ANSI_RESET = "\033[0m"

log.info """
        ===========================================
         AMPSEQ_0.0 (dev : prototype)
         Used parameters:
        -------------------------------------------
         --execution_mode     : ${params.execution_mode}
         --panels_settings    : ${params.panels_settings}
         --containers_dir     : ${params.containers_dir}
         --results_dir        : ${params.results_dir}
         --containers_dir     : ${params.containers_dir}
         --genotyping_gatk    : ${params.genotyping_gatk}
         --genotyping_bcftools: ${params.genotyping_bcftools}
         --skip_bqsr          : ${params.skip_bqsr}

         (in-country)
         --run_id             : ${params.run_id}
         --bcl_dir            : ${params.bcl_dir}
         --lane               : ${params.lane}
         --study_name         : ${params.study_name}
         --read_group         : ${params.read_group}
         --library            : ${params.library}

         (irods)
         --irods_manifest     : ${params.irods_manifest}

         (aligned_bams)
         --aligned_bams_mnf   : ${params.aligned_bams_mnf}
         
         (s3)
         --download_from_s3   : ${params.download_from_s3}
         --upload_to_s3       : ${params.upload_to_s3}
         --s3_uuid            : ${params.s3_uuid}
         --s3_bucket_input    : ${params.s3_bucket_input}
         --s3_bucket_output   : ${params.s3_bucket_output}

         (DEBUG)
         --DEBUG_tile_limit   : ${params.DEBUG_tile_limit}
         --DEBUG_takes_n_bams : ${params.DEBUG_takes_n_bams}

        ------------------------------------------
         Runtime data:
        -------------------------------------------
         Running with profile:   ${ANSI_GREEN}${workflow.profile}${ANSI_RESET}
         Running as user:        ${ANSI_GREEN}${workflow.userName}${ANSI_RESET}
         Launch dir:             ${ANSI_GREEN}${workflow.launchDir}${ANSI_RESET}
         Base dir:               ${ANSI_GREEN}${baseDir}${ANSI_RESET}
         ------------------------------------------
         """
         .stripIndent()


def printHelp() {
  log.info """
  Usage:
    (irods)
    nextflow run /path/to/ampseq-pipeline/main.nf -profile sanger_lsf 
        --execution_mode irods
        --irods_manifest ./input/irods_smallset.tsv

    (incountry)
    nextflow /path/to/ampseq-pipeline/main.nf -profile sanger_lsf
                --execution_mode in-country --run_id 21045
                --bcl_dir /path/to/my_bcl_dir/ --lane 1
                --study_name test --read_group rg_test --library lib

  Description:
    Ampseq is a bioinformatics analysis pipeline for amplicon sequencing data.
    Currently supporting alignment and SNP variant calling on paired-end Illumina sequencing data.

    *for a complete description of input files and parameters check:
    https://gitlab.internal.sanger.ac.uk/malariagen1/ampseq-pipeline/

  Options:
    Inputs:
      (required)
      --execution_mode : sets the entry point for the pipeline ("irods", "aligned_bams" or "in-country")
      
      (incountry required)
      --run_id : id to be used for the batch of data to be processed
      --bcl_dir: path to a miseq directory
      --lane : <str>
      --study_name : <str>
      --read_group : <str>
      --library : <str>

      (irods required)
      --irods_manifest : an tsv containing information of irods data to fetch
      
      (if s3)
      --s3_uuid : <str> a universally unique id which will be used to fetch data from s3, if is not provided, the pipeline will not retrieve miseq runs from s3
      --s3_bucket_input : <str> s3 bucket name to fetch data from
      --upload_to_s3 : <bool> sets if needs to upload output data to an s3 bucket
      --s3_bucket_output : <str> s3 bucket name to upload data to

    Settings:
      --results_dir : <path>, output directory (Default: $launchDir/output/)
      --panels_settings : <path>, path to panel_settings.csv
      --containers_dir : <path>, path to a dir where the containers are located

      (genotyping)
      --gatk3: <str> path to GATK3 GenomeAnalysisTK.jar file
      --skip_bqsr : <bool> skip BQSR step in GATK genotyping procedure

    Additional options:
      --help (Prints this help message. Default: false)
    
    Profiles:
      sanger_lsf : run the pipeline on farm5 lsf (recommended)
      sanger_default : run the pipeline on farm5 local settings (only for development)
   """.stripIndent()
}

def validate_general_params(){
  /*
  count errors on parameters which must be provided regardless of the workflow which will be executed
  
  returns
  -------
  <int> number of errors found
  */
  def err = 0
  def valid_execution_modes = ["in-country", "irods", "aligned_bams"]

  // check if execution mode is valid
  if (!valid_execution_modes.contains(params.execution_mode)){
    log.error("The execution mode provided (${params.execution_mode}) is not valid. valid modes = ${valid_execution_modes}")
    err += 1
  }
  // check if output dir exists, if not create the default
  if (params.results_dir){
    results_path = file(params.results_dir)
    if (!results_path.exists()){
      log.warn("${results_path} does not exists, the dir will be created")
      results_path.mkdir()
    }
  }
  
  // if S3 is requested, check if all s3 required parameters were provided
  // check S3 input bucket
  if (!(params.s3_bucket_input==null)){
    if (params.s3_uuid == null){
      log.error("A s3 uuid parameter must be provided if a s3 bucket input is provided'.")
      errors += 1
    } 
  }
  // check S3 output bucket
  if (params.upload_to_s3){
    if (params.s3_bucket_output == null){
      log.error("A s3_bucket_output parameter must be provided if upload_to_s3 is set to '${params.upload_to_s3}'.")
      errors += 1
    }
    if (params.s3_uuid==null){
      log.error("A s3_uuid must be provided if upload_to_s3 is required")
      errors += 1
    }
  }
  // -------------------------------------------------------------/
  // NOTE: aligned_bams mode maybe depreciated in the near future
  //       this will likely be removed
  if (params.execution_mode == "aligned_bams"){
    if (params.aligned_bams_mnf == null){
      log.error("An aligned_bams_mnf must be provided for execution mode '${params.execution_mode}'.")
      errors += 1
    }
    if (params.aligned_bams_mnf){
      aligned_bams_manifest = file(params.aligned_bams_mnf)
      if (!aligned_bams_manifest.exists()){
        log.error("The aligned bams manifest file specified (${params.aligned_bams_mnf}) does not exist.")
        errors += 1
      }
    }
  }
  // -------------------------------------------------------------/

  return err
}

def validate_parameters(){
  def errors = 0
  // check general params
  errors += validate_general_params()
  
  // count errors of irods params, if need be
  if (params.execution_mode == "irods"){
    errors += count_irods_to_reads_params_errors()
  }
  // count errors of incountry params, if need be
  if (params.execution_mode == "in-country"){
    errors += count_miseq_to_reads_params_errors()
  }
}

// Main entry-point workflow
workflow {
  // --- Print help if requested -------------------------------------------
  // Show help message
  if (params.help) {
      printHelp()
      exit 0
  }

  // check parameters provided
  validate_parameters()

  // -- MAIN-EXECUTION ------------------------------------------------------
  // prepare panel resource channels 
  PARSE_PANEL_SETTINGS(params.panels_settings)

  reference_ch = PARSE_PANEL_SETTINGS.out.reference_ch // tuple(reference_file, panel_name, snp_list)
  annotations_ch = PARSE_PANEL_SETTINGS.out.annotations_ch // tuple(panel_name, design_file)

  // Files required for GRC creation
  Channel.fromPath(params.grc_settings_file_path, checkIfExists: true)
  chrom_key_file = Channel.fromPath(params.chrom_key_file_path, checkIfExists: true)
  kelch_reference_file = Channel.fromPath(params.kelch_reference_file_path, checkIfExists: true)
  codon_key_file = Channel.fromPath(params.codon_key_file_path, checkIfExists: true)
  drl_information_file = Channel.fromPath(params.drl_information_file_path, checkIfExists: true)

  if (params.execution_mode == "in-country") {
    // process in country entry point
    MISEQ_TO_READS(reference_ch)
    bam_files_ch = MISEQ_TO_READS.out.bam_files_ch
    file_id_reference_files_ch = MISEQ_TO_READS.out.file_id_reference_files_ch
    file_id_to_sample_id_ch = MISEQ_TO_READS.out.file_id_to_sample_id_ch
  }

  if (params.execution_mode == "irods") {
    // process IRODS entry point
    SANGER_IRODS_TO_READS(params.irods_manifest, reference_ch)
    // setup channels for downstream processing
    bam_files_ch = SANGER_IRODS_TO_READS.out.bam_files_ch // tuple (file_id, bam_file, run_id)
    file_id_reference_files_ch = SANGER_IRODS_TO_READS.out.file_id_reference_files_ch
    file_id_to_sample_id_ch = SANGER_IRODS_TO_READS.out.file_id_to_sample_id_ch
  }

  if (params.execution_mode == "aligned_bams"){
    // get bam files channel
    mnf_ch = Channel.fromPath(params.aligned_bams_mnf, checkIfExists: true)
                        | splitCsv(header:true, sep:',')
    bam_files_ch = mnf_ch | map {row -> tuple(row.file_id, row.bam_file, row.bam_idx)}
    
    // get sample tags to panel resources relationship channel
    ref_to_sample = mnf_ch | map {row -> tuple(row.file_id, row.panel_name)} 

    ref_to_sample
      | combine(reference_ch, by:1) // tuple(panel_name, file_id, reference_file, snp_list)
      | map {it -> tuple(it[1], it[0], it[2], it[3])} // tuple(file_id, panel_name, fasta_file, snp_list)
      | set { file_id_reference_files_ch}
  }

  // Reads to variants
  READS_TO_VARIANTS(bam_files_ch, file_id_reference_files_ch, annotations_ch, file_id_to_sample_id_ch)
  lanelet_manifest_file = READS_TO_VARIANTS.out.lanelet_manifest

  // Variants to GRCs
  VARIANTS_TO_GRCS(lanelet_manifest_file, chrom_key_file, kelch_reference_file, codon_key_file, drl_information_file)

}


// -------------- Check if everything went okay -------------------------------
workflow.onComplete {
    if (workflow.success) {
        log.info """
            ===========================================
            ${ANSI_GREEN}Finished in ${workflow.duration}
            See the report here ==> ${ANSI_RESET}/SOMEDIR/XXX_report.html
            """
            .stripIndent()
    } else {
        log.info """
            ===========================================
            ${ANSI_RED}Finished with errors!${ANSI_RESET}
            """
            .stripIndent()
    }
}
