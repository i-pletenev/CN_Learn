#!/bin/bash
####################################################################
# Script : canoes_extract.sh                                       #
# Author : Vijay Kumar                                             #
# Date   : 4/5/2019                                                #
#                                                                  #
# This script extracts the read depth information for subsequent   #
# analysis by the CANOES pipeline.                                 #
#                                                                  #
# IMPORTANT NOTE: This for loop that processes the samples can be  #
# easily modified to run in parallel on local clusters or on other #
# cloud infrastructures.                                           #
#                                                                  #
# (c) 2019 - Vijay Kumar                                           #
# Licenced under the GNU General Public License 3.0.               #    
####################################################################
echo "Job started on `hostname` at `date`"

source TBD/config.params

############################################
# STEP 0: Declare variables and file names #
############################################
CANOES_READS_FILE='canoes_reads'
CONS_READS=${DATA_CANOES_DIR}'cons_canoes_reads' 

#######################################################################################
# STEP 1: Extract Read Counts for each sample in a single step and submit separate jobs
#######################################################################################
touch ${DATA_CANOES_DIR}${CANOES_READS_FILE}
cd ${DATA_CANOES_DIR}
split -l 4 ${BAM_FILE_LIST_W_PATH} list_of_bam_split

split_file_list=`ls list_of_bam_split*`

for split_file in ${split_file_list};
do
${DOCKER_COMMAND}${BEDTOOLS_DIR}bedtools multicov -bams `cat ${DATA_CANOES_DIR}${split_file} \
                                     | tr "\n" " "` -bed ${TARGET_PROBES} -q 20 \
                                     > ${DATA_CANOES_DIR}${CANOES_READS_FILE}_${split_file}
done

echo "Job ended on `hostname` at `date`"
