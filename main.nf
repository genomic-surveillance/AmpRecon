#!/usr/bin/env nextflow
// Copyright (C) 2023 Genome Surveillance Unit/Genome Research Ltd.

// enable dsl2
nextflow.enable.dsl = 2

// --- import modules ---------------------------------------------------------
// - workflows

include { parse_panel_settings } from './modules/parse_panels_settings.nf'
include { miseq_to_reads_parameter_check } from './workflows/miseq_to_reads.nf'
include { irods_to_reads_parameter_check } from './workflows/sanger_irods_to_reads.nf'
include { fastq_parameter_check } from './workflows/fastq_entry_point.nf'
include { SANGER_IRODS_TO_READS } from './workflows/sanger_irods_to_reads.nf'
include { MISEQ_TO_READS } from './workflows/miseq_to_reads.nf'
include { FASTQ_ENTRY_POINT } from './workflows/fastq_entry_point.nf'
include { READS_TO_VARIANTS } from './workflows/reads_to_variants.nf'
include { VARIANTS_TO_GRCS } from './workflows/variants_to_grcs.nf'


// logging info ----------------------------------------------------------------
// This part of the code is based on the one present at FASTQC PIPELINE (https://github.com/angelovangel/nxf-fastqc/blob/master/main.nf)

/*
* ANSI escape codes to color output messages
*/
ANSI_GREEN = "\033[1;32m"
ANSI_RED = "\033[1;31m"
ANSI_RESET = "\033[0m"

log.info """
        ===========================================
         AMPRECON 1.3.0
         Used parameters:
        -------------------------------------------
         --execution_mode     : ${params.execution_mode}
         --panels_settings    : ${params.panels_settings}
         --containers_dir     : ${params.containers_dir}
         --results_dir        : ${params.results_dir}
         --containers_dir     : ${params.containers_dir}
         --grc_settings_file_path: ${params.grc_settings_file_path}
         --chrom_key_file_path: ${params.chrom_key_file_path}
         --kelch_reference_file_path: ${params.kelch_reference_file_path}
         --codon_key_file_path: ${params.codon_key_file_path}
         --drl_information_file_path: ${params.drl_information_file_path}
         --batch_id             : ${params.batch_id}

         (in-country)
         --bcl_dir            : ${params.bcl_dir}
         --ena_study_name     : ${params.ena_study_name}
         --manifest_path      : ${params.manifest_path}

         (irods)
         --irods_manifest     : ${params.irods_manifest}

         (fastq_entry_point)
         --fastq_manifest     : ${params.fastq_manifest}

         (s3)
         --upload_to_s3       : ${params.upload_to_s3}
         --s3_uuid            : ${params.s3_uuid}
         --s3_bucket_output   : ${params.s3_bucket_output}

         (grc)
         --no_plasmepsin      : ${params.no_plasmepsin}
         --no_kelch           : ${params.no_kelch}

         (DEBUG)
         --DEBUG_tile_limit   : ${params.DEBUG_tile_limit}
         --DEBUG_takes_n_bams : ${params.DEBUG_takes_n_bams}
         --DEBUG_no_coi       : ${params.DEBUG_no_coi}
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
      --execution_mode irods  --batch_id 21045
      --irods_manifest ./input/irods_smallset.tsv
      --chrom_key_file_path chromKey.txt
      --grc_settings_file_path grc_settings.json
      --drl_information_file_path DRLinfo.txt
      --codon_key_file_path codonKey.txt
      --kelch_reference_file_path kelchReference.txt
      --containers_dir ./containers_dir/ 

    (incountry)
    nextflow /path/to/ampseq-pipeline/main.nf -profile sanger_lsf
      --execution_mode in-country --batch_id 21045
      --bcl_dir /path/to/my_bcl_dir/ --ena_study_name test
      --manifest_path manifest.tsv
      --chrom_key_file_path chromKey.txt
      --grc_settings_file_path grc_settings.json
      --drl_information_file_path DRLinfo.txt
      --codon_key_file_path codonKey.txt
      --kelch_reference_file_path kelchReference.txt
      --containers_dir ./containers_dir/

    (fastq_entry_point)
    nextflow /path/to/ampseq-pipeline/main.nf -profile sanger_lsf
      --execution_mode fastq --batch_id 21045
      --fastq_manifest ./input/fastq_smallset.tsv
      --chrom_key_file_path chromKey.txt
      --grc_settings_file_path grc_settings.json
      --drl_information_file_path DRLinfo.txt
      --codon_key_file_path codonKey.txt
      --kelch_reference_file_path kelchReference.txt
      --containers_dir ./containers_dir/

  Description:
    Ampseq is a bioinformatics analysis pipeline for amplicon sequencing data.
    Currently supporting alignment and SNP variant calling on paired-end Illumina sequencing data.

    *for a complete description of input files and parameters check the README file in the code repository

  Options:
    Inputs:
      (required)
      --execution_mode : sets the entry point for the pipeline ("irods" or "in-country")
      
      (incountry required)
      --batch_id : id to be used for the batch of data to be processed. 
                   This ID is only used to prefix output files and readgroup names in cram files.
                   It can be a run ID or any other identifier that makes sense for your data.
      --bcl_dir: path to a miseq directory
      --ena_study_name : <str>
      --manifest_path: <str> path to the manifest file

      (irods required)
      --irods_manifest : a tsv containing information of irods data to fetch
      
      (fastq entry point required)
      --fastq_manifest: <str> path to the manifest file

      (if s3)
      --s3_uuid : <str> A s3_uuid must be provided if --upload_to_s3 is required
      --upload_to_s3 : <bool> sets if needs to upload output data to an s3 bucket
      --s3_bucket_output : <str> s3 bucket name to upload data to

      (grc_creation)
      --batch_id : id to be used as a prefix for the output GRC files.
                   This ID is only used to prefix output files and readgroup names in cram files.
                   It can be a run ID or any other identifier that makes sense for your data.
      --grc_settings_file_path: <str> path to the GRC settings file.
      --chrom_key_file_path: <str> path to the chrom key file
      --kelch_reference_file_path: <str> path to the kelch13 reference sequence file
      --codon_key_file_path: <str> path to the codon key file
      --drl_information_file_path: <str> path to the drug resistance loci information file

    Settings:
      --results_dir : <path>, output directory (Default: $launchDir/output/)
      --panels_settings : <path>, path to panel_settings.csv
      --containers_dir : <path>, path to a dir where the containers are located


    Additional options:
      --help (Prints this help message. Default: false)
    
    Profiles:
      standard (default): run locally using singularity
      run_locally : run locally using what is available on the system environment (no containers)
      sanger_local : run the pipeline on Sanger HPC
      sanger_lsf : run the pipeline by submiting tasks as individual jobs to lsf queue on Sanger HPC
      sanger_tower : run the pipeline under nextflow tower
   """.stripIndent()
}

// Main entry-point workflow
workflow {
  // --- Print help if requested -------------------------------------------
  // Show help message
  if (params.help) {
      printHelp()
      exit 0
  }

  // validate parameters
  validate_general_params()

  // -- MAIN-EXECUTION ------------------------------------------------------
  // prepare panel resource channels
  ref_and_annt_ch = parse_panel_settings(params.panels_settings)
  reference_ch = ref_and_annt_ch[0] // tuple(reference_file, panel_name, snp_list)
  annotations_ch = ref_and_annt_ch[1] // tuple(panel_name, design_file)

  // files required for GRC creation
  Channel.fromPath(params.grc_settings_file_path, checkIfExists: true)
  chrom_key_file = Channel.fromPath(params.chrom_key_file_path, checkIfExists: true)
  codon_key_file = Channel.fromPath(params.codon_key_file_path, checkIfExists: true)
  drl_information_file = Channel.fromPath(params.drl_information_file_path, checkIfExists: true)

  if (params.no_kelch == false) {
    kelch_reference_file = Channel.fromPath(params.kelch_reference_file_path, checkIfExists: true)
  } else {
    kelch_reference_file = Channel.empty()
  }

  if (params.execution_mode == "in-country") {
    // process in country entry point
    miseq_to_reads_parameter_check()
    manifest = Channel.fromPath(params.manifest_path, checkIfExists: true)
    MISEQ_TO_READS(manifest, reference_ch)
    fastq_files_ch = MISEQ_TO_READS.out.fastq_files_ch
    file_id_reference_files_ch = MISEQ_TO_READS.out.file_id_reference_files_ch
    file_id_to_sample_id_ch = MISEQ_TO_READS.out.file_id_to_sample_id_ch
  }

  if (params.execution_mode == "irods") {
    irods_to_reads_parameter_check()
    // process IRODS entry point
    manifest = Channel.fromPath(params.irods_manifest, checkIfExists: true)
    SANGER_IRODS_TO_READS(manifest, reference_ch)
    // setup channels for downstream processing
    fastq_files_ch = SANGER_IRODS_TO_READS.out.fastq_ch // tuple (file_id, bam_file, batch_id)
    file_id_reference_files_ch = SANGER_IRODS_TO_READS.out.file_id_reference_files_ch
    file_id_to_sample_id_ch = SANGER_IRODS_TO_READS.out.file_id_to_sample_id_ch
  }

  if (params.execution_mode == "fastq") {
    fastq_parameter_check() 
    // parse manifest
    manifest = Channel.fromPath(params.fastq_manifest, checkIfExists: true)
    FASTQ_ENTRY_POINT(manifest, reference_ch)
    // setup channels for downstream processing
    fastq_files_ch = FASTQ_ENTRY_POINT.out.fastq_files_ch // tuple (file_id, fastq_ch, path/to/reference/genome) 
    file_id_reference_files_ch = FASTQ_ENTRY_POINT.out.file_id_reference_files_ch// tuple (file_id, panel_name, path/to/reference/genome, snp_list)
    file_id_to_sample_id_ch = FASTQ_ENTRY_POINT.out.file_id_to_sample_id_ch// tuple (file_id, sample_id)  
  }

  // Reads to variants
  READS_TO_VARIANTS(fastq_files_ch, file_id_reference_files_ch, annotations_ch,
                    file_id_to_sample_id_ch)
  lanelet_manifest_file = READS_TO_VARIANTS.out.lanelet_manifest

  // Variants to GRCs
  VARIANTS_TO_GRCS(manifest, lanelet_manifest_file, chrom_key_file, kelch_reference_file,
                  codon_key_file, drl_information_file)
}


// -------------- Check if everything went okay -------------------------------
workflow.onComplete {
    if (workflow.success) {
        log.info """
            ===========================================
            ${ANSI_GREEN}Finished in ${workflow.duration}
            See the report here ==> ${ANSI_RESET}${workflow.launchDir}/report.html
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

def __check_if_params_file_exist(param_name, param_value){
  // --- GRC SETTINGS ---
  def error = 0

  if (!(param_value==null)){
    param_file = file(param_value)
    if (!param_file.exists()){
      log.error("${param_file} does not exist")
      error +=1
    }
  }

  if (param_value==null){
    log.error("${param_name} must be provided")
    error +=1
  }
  // ----------------------
  return error
}

def validate_general_params(){
  /*
  count errors on parameters which must be provided regardless of the workflow which will be executed
  
  returns
  -------
  <int> number of errors found
  */

  def error = 0
  def valid_execution_modes = ["in-country", "irods", "fastq"]

  // check if execution mode is valid
  if (!valid_execution_modes.contains(params.execution_mode)){
    log.error("The execution mode provided (${params.execution_mode}) is not valid. valid modes = ${valid_execution_modes}")
    error += 1
  }

  // check if resources were provided
  error += __check_if_params_file_exist("grc_settings_file_path", params.grc_settings_file_path)
  error += __check_if_params_file_exist("panels_settings", params.panels_settings) 
  error += __check_if_params_file_exist("chrom_key_file_path", params.chrom_key_file_path) 
  error += __check_if_params_file_exist("codon_key_file_path", params.codon_key_file_path)
  error += __check_if_params_file_exist("drl_information_file_path", params.drl_information_file_path)

  if (params.no_kelch == false) {
    error += __check_if_params_file_exist("kelch_reference_file_path", params.kelch_reference_file_path)
  }
  
  // raise WARNING if debug params were set
  if (!params.DEBUG_takes_n_bams == null){
    log.warn("[DEBUG] takes_n_bams was set to ${params.DEBUG_takes_n_bams}")
  }

  if (!params.DEBUG_tile_limit == null){
    log.warn("[DEBUG] tile_limit was set to ${params.DEBUG_tile_limit}")
  }

  if (params.DEBUG_no_coi == true){
    log.warn("[DEBUG] no_coi was set to ${params.DEBUG_no_coi}")
  }
  // -------------------------------------------

  // check if output dir exists, if not create the default path
  if (params.results_dir){
    results_path = file(params.results_dir)
    if (!results_path.exists()){
      log.warn("${results_path} does not exists, the dir will be created")
      results_path.mkdir()
    }
  }

  if ((params.DEBUG_no_coi == false) && (params.mccoil_repopath != "/app/THEREALMcCOIL/")){
    mccoil_path = file(params.mccoil_repopath)
    if (mccoil_path.exists() == false){
      log.error("""
      The mccoil_repopath provided (${mccoil_path}) does not exists.
      This can happen if you do not use the containers provided or setup an invalid custom path.
      Please provide a valid custom installation path of the McCOIL library.
      """)
      error+=1
    }
  }
  // if S3 is requested, check if all S3 required parameters were provided

  // check S3 output bucket
  if (params.upload_to_s3){
    if (params.s3_bucket_output == null){
      log.error("A s3_bucket_output parameter must be provided if upload_to_s3 is set to '${params.upload_to_s3}'.")
      error += 1
    }
    if (params.s3_uuid==null){
      log.error("A s3_uuid must be provided if upload_to_s3 is required")
      error += 1
    }
  }

  if (error > 0) {
    log.error("Parameter errors were found, the pipeline will not run")
    exit 1
  }
}

