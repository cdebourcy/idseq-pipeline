#!/bin/bash

DATE=`date '+%Y-%m-%d'`


##### PARAMETERS TO EDIT #####

## Output path. Deploying to production consists in setting DESTINATION=s3://czbiohub-infectious-disease/references.
# To test, you can choose a subfolder of that folder. Choosing a separate folder would require editing the role policy
# of the gsnap/rapsearch machines that perform the indexing to ensure S3 write access.
DESTINATION=s3://idseq-database/${DATE}/references

## To pull NCBI references through ncbitool, which archives and records versions, set URL_PREFIX=''.
# To pull the latest files from NCBI without using ncbitool (no version information), set URL_PREFIX=ftp://ftp.ncbi.nlm.nih.gov.
URL_PREFIX=ftp://ftp.ncbi.nlm.nih.gov

## Instances with adequate resources for making gsnap and rapsearch indexes.
# Need to have write access to DESTINATION.
RAPSEARCH_SERVER_IP=54.191.193.210
GSNAP_SERVER_IP=34.211.67.166


##### COMMANDS #####

## Install idseq-pipeline
# echo 'Installing idseq-pipeline...'
# pip install git+https://github.com/chanzuckerberg/idseq-pipeline.git

## Archive path
ARCHIVE_FOLDER=s3://idseq-database/${DATE}/archive
echo Old indexes will be archived to ${ARCHIVE_FOLDER}

## Make GSNAP index
dest2=s3://idseq-database/alignment_indexes/${DATE}
echo 'Making new GSNAP index...'
echo "INPUT_FASTA_S3: ${URL_PREFIX}/blast/db/FASTA/nt.gz"
echo "OUTPUT NAME: nt_k16"
echo "OUTPUT PATH S3: $dest2"
INPUT_FASTA_S3=${URL_PREFIX}/blast/db/FASTA/nt.gz SERVER_IP=${GSNAP_SERVER_IP} KEY_S3_PATH=s3://idseq-secrets/idseq-production.pem OUTPUT_PATH_S3=$dest2 OUTPUT_NAME=nt_k16 idseq_pipeline gsnap_indexing

## Make RAPSearch2 index
echo 'Making new RAPSearch2 index...'
INPUT_FASTA_S3=${URL_PREFIX}/blast/db/FASTA/nr.gz SERVER_IP=${RAPSEARCH_SERVER_IP} KEY_S3_PATH=s3://czbiohub-infectious-disease/idseq-alpha.pem OUTPUT_PATH_S3=$dest2 OUTPUT_NAME=nr_rapsearch idseq_pipeline rapsearch_indexing

## Make taxonomy lineage files
echo 'Making new taxonomy lineage files...'
dest2=s3://idseq-database/taxonomy/${DATE}
OUTPUT_PATH_S3=$dest2 INPUT=${URL_PREFIX}/pub/taxonomy/taxdump.tar.gz idseq_pipeline lineages

## Make accession2taxid mapping and record diff with old accession list
echo 'Making new accession2taxid mapping...'
dest2=s3://idseq-database/alignment_data/${DATE}
MAPPING_FILES=${URL_PREFIX}/pub/taxonomy/accession2taxid/nucl_est.accession2taxid.gz,${URL_PREFIX}/pub/taxonomy/accession2taxid/nucl_gb.accession2taxid.gz,${URL_PREFIX}/pub/taxonomy/accession2taxid/nucl_gss.accession2taxid.gz,${URL_PREFIX}/pub/taxonomy/accession2taxid/nucl_wgs.accession2taxid.gz,${URL_PREFIX}/pub/taxonomy/accession2taxid/pdb.accession2taxid.gz,${URL_PREFIX}/pub/taxonomy/accession2taxid/prot.accession2taxid.gz
idseq_pipeline curate_accession2taxid --mapping_files ${MAPPING_FILES} --nr_file ${URL_PREFIX}/blast/db/FASTA/nr.gz --nt_file ${URL_PREFIX}/blast/db/FASTA/nt.gz --output_s3_folder $dest2 --previous_mapping s3://czbiohub-infectious-disease/references/accession2taxid.db.gz
