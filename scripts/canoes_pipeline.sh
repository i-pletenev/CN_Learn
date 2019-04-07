#!/bin/bash
#################################################################
# Author: Vijay Kumar
# Date  : 5/3/2018
# This is the master script for the CANOES pipeline that executes 
# all other steps via other shell scripts or R/Python scripts.   
#
# Prereqs: A text file with the list of sample names
#################################################################

echo "Job started on `hostname` at `date`"

source /data/test_installation/CN_Learn/config.params

############################################
# STEP 0: Declare variables and file names #
############################################
CANOES_READS_FILE='canoes_reads'
CONS_READS=${DATA_CANOES_DIR}'cons_canoes_reads' 

NUM_OF_PROBES=`wc -l < ${TARGET_PROBES}`

##############################################
# Generate the file with the list of samples #
##############################################
echo 'SAMPLE' > ${DATA_CANOES_DIR}sample_seq
num_samples=`cat ${BAM_FILE_LIST_W_PATH} | wc -l`
for samp in $(seq 1 ${num_samples});
do
echo "S${samp}" >> ${DATA_CANOES_DIR}sample_seq
done

echo 'SAMPLE_NAME' > ${DATA_CANOES_DIR}sample_names
cat ${SAMPLE_LIST} >> ${DATA_CANOES_DIR}sample_names
paste -d , ${DATA_CANOES_DIR}sample_seq ${DATA_CANOES_DIR}sample_names \
                             > ${DATA_CANOES_DIR}sample_map_canoes.csv

cp ${DATA_CANOES_DIR}sample_map_canoes.csv ${DATA_DIR}sample_map_canoes.csv

#######################################################################################
# STEP 1: Extract Read Counts for each sample in a single step and submit separate jobs
#######################################################################################
touch ${DATA_CANOES_DIR}${CANOES_READS_FILE}
cd ${DATA_CANOES_DIR}
split -l 4 ${BAM_FILE_LIST_W_PATH} list_of_bam_split

split_file_list=`ls list_of_bam_split* | tail -n+2 | tail -1`

for split_file in ${split_file_list};
do
docker run --rm -ti -v ${PROJ_DIR}:${PROJ_DIR} girirajanlab/cnlearn \
${BEDTOOLS_DIR}bedtools multicov -bams `cat ${DATA_CANOES_DIR}${split_file} \
                                     | tr "\n" " "` -bed ${TARGET_PROBES} -q 20 \
                         > ${DATA_CANOES_DIR}${CANOES_READS_FILE}_${split_file}
done

###################################################################################################
# STEP 2: Make sure the number of rows in each output file matches with the number of target probes 
###################################################################################################
cd ${DATA_CANOES_DIR}
split_file_list=`ls list_of_bam_split* | grep "^list_of_bam_split"`
cat ${TARGET_PROBES} > ${CONS_READS}
for split_file in ${split_file_list};
do
num_of_rows_input=`wc -l < ${DATA_CANOES_DIR}${CANOES_READS_FILE}_${split_file}`
if [ ${NUM_OF_PROBES} = ${num_of_rows_input} ];
then
cat ${DATA_CANOES_DIR}${CANOES_READS_FILE}_${split_file} | cut -f 4,5,6,7 \
                                            > ${DATA_CANOES_DIR}'temp_file'
paste ${CONS_READS} ${DATA_CANOES_DIR}'temp_file' > ${DATA_CANOES_DIR}'temp_file2'
mv ${DATA_CANOES_DIR}'temp_file2' ${CONS_READS}
else
echo "Error in probe counts in file ${DATA_CANOES_DIR}${CANOES_READS_FILE}_${split_file}"
fi
done

##############################################
# STEP 3: Extract GC content for each interval
##############################################
docker run --rm -ti -v ${PROJ_DIR}:${PROJ_DIR} girirajanlab/cnlearn \
java -Xmx2000m -Djava.io.tmpdir=${DATA_LOGS_DIR} \
                   -jar ${GATK_SW_DIR}GenomeAnalysisTK.jar \
                   -T GCContentByInterval -L ${TARGET_PROBES} \
                   -R ${REF_GENOME} -o ${DATA_CANOES_DIR}gc.txt

##############################################################################################
# STEP 4: Execute R script to merge data. This is needed because multicov command was executed 
#         for just four samples via separate jobs, to parallalize data extraction manually.
##############################################################################################
docker run --rm -ti -v ${PROJ_DIR}:${PROJ_DIR} girirajanlab/cnlearn \
Rscript --vanilla ${RSCRIPTS_DIR}canoes_merge_files.r \
                      ${SCRIPTS_DIR} ${DATA_CANOES_DIR} ${CONS_READS} canoes_calls.csv


#######################################################
# Copy the output files to the final output directory #
#######################################################
cp ${DATA_CANOES_DIR}canoes_calls.csv ${DATA_DIR}'canoes_calls.csv'


echo "Job ended on `hostname` at `date`"