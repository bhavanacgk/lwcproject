#--------------------------------------------------------------------
#      Title:              execCommandForRollUp.ksh
#      Author:             Swati Bhargava
#      Date:               07-15-2004
#
#      Proprietary:        THIS SOFTWARE IS THE PROPERTY OF FIDELITY
#                          INVESTMENTS AND IS FOR INTERNAL USE ONLY
#
#      Description         This shell will be used to process 
#                          a list of commands specified in this
#                          script's command file identified in
#                          the config file  
#
#
#      (C) Copyright Fidelity Investment 2000.  All rights reserved.
#
#--------------------------------------------------------------------


PGM_NM=$0
BaseExe=`basename ${PGM_NM} | awk -F'.' '{print $1}'`

LOG_FILE=${BATCH_LOG_DIR:? BATCH_LOG_DIR is not set}/daily/${BaseExe}.log.$$
MAIL_LOG=$BATCH_LOG_DIR/daily/temp_roll.log
LOAD_LOG=$BATCH_LOG_DIR/daily/load.log

CUR_DATE=`date +%d.%h.%y-%H:%M`
TEMP_LOG=$BATCH_LOG_DIR/daily/mail_roll.log

# Create empty log file
>$LOG_FILE

. ${BATCH_HOME:? BATCH_HOME is not set}/bin/ta/logFunction.ksh
. ${BATCH_HOME:? BATCH_HOME is not set}/bin/admin/getConfig.ksh

# vars_reqd contains the required variables that need to be retrieved from config file
typeset vars_reqd="ORACLE_UNAME ORACLE_PASSWD ORACLE_SID ORACLE_OWNER RESTART_FILE IN_DATA_DIR ZIP_DATA_FILE CLIENT_DATA_FILE OUT_DATA_DIR PROC_START_TIME PROC_END_TIME SLEEP_TIME DEV_MAIL_GROUP PROD_MAIL_GROUP OTHER_MAIL_GROUP"
typeset vars_opts=""

logmsg -m "Starting ${PGM_NM} " -l $LINENO -p ${PGM_NM} -t;
typeset v_cfv_file=""
typeset USAGE="${PGM_NM} -c <ConfigFile> [-s <Section>]"

#===============================================================
#                    FUNCTION DEFINITIONS
#===============================================================

#---------------------------------------------------------------
# function: reqdParamTest
#
# purpose:  Checks if all the parameters required in the shell
#           scripts are retrieved from the configuration table
#
# notes:    parameters to validate are set in the variable
#           vars_reqd
#---------------------------------------------------------------
unset -f reqdParamTest
function reqdParamTest
{
        fncname="reqdParamTest"
        ret_val=0

        # Set for debugging (+o=off/-o=on)
        if [[ "${DEBUG:-N}" = "Y" ]]
        then
             set -vv
        fi

        logmsg -m "Starting ${fncname} " -l $LINENO -p ${fncname} -t;

        if [[ $# -ne 1 ]]
        then
                echo "Too many arguments"
        fi

        v_reqd_params=$1;
        v_status="SUCCESS"

        logmsg -m "Processing reqdParamTest :" -l $LINENO -p ${PGM_NM} -t;

        #--------------------------------------------------
        # Testing if all required parameters were retrieved
        #--------------------------------------------------

        for testvar in $v_reqd_params
        do
                test=""
                cmd="print \${$testvar}"
                test=`eval ${cmd}`

                logmsg -m "$testvar"

                if [[ -z "${test}" ]]
                then
                     if [[ -z ${LOG_FILE} ]]
                     then
                           print "$testvar was not provided"
                           v_status="FAIL"
                     else
                           logmsg -m "$testvar was not provided" -l $LINENO;
                           v_status="FAIL"
                     fi
                fi
        done

        if [[ "$v_status" = "FAIL" ]]
        then
               print "FATAL ERROR SEE LOGFILE"               
               echo "See Log $LOG_FILE for errors.  The process has stopped." > ${TEMP_LOG}
               mailError
               logmsg -m "See Log for Errors" -l $LINENO -p ${PGM_NM} -t;
               ret_val=1
        fi

        logmsg -m "Finished Processing reqdParamTest :" -l $LINENO -p ${PGM_NM};
        set +x

        return $ret_val;

} # end reqdParamTest

#---------------------------------------------------------------
# function: mailError
#
# purpose:  Mail errors to the mailing group specified in 
#           the config file
#
# notes:    No mail is sent if the parameters are not provided.
#---------------------------------------------------------------

function mailError
{
	if [[ "${CYCLE_ENV_SETTING}" == "DEV" ]] ; then	    
	 mailx -s "Territory Mapping: Zipcode Rollup error at $CUR_DATE" "$DEV_MAIL_GROUP" <${TEMP_LOG}
	elif [[ "${CYCLE_ENV_SETTING}" == "PROD" ]] ; then
	 mailx -s "Territory Mapping: Zipcode Rollup error at $CUR_DATE" "$PROD_MAIL_GROUP" <${TEMP_LOG}
	else
	 mailx -s "Territory Mapping: Zipcode Rollup error at $CUR_DATE" "$OTHER_MAIL_GROUP" <${TEMP_LOG}
	fi	    
} # end mailError

function compressFile
{
	compress -f $INPUT_FILE_NAME
	exit_status=$?
	if [[ $exit_status -ne 0 ]]; then
	   logmsg -m "ERROR cannot compress $INPUT_FILE_NAME - Compress manually and force complete this job" -l $LINENO -p $0;	   
	fi
} # end compressFile

function movDataFiles
{
	INPUT_FILE_NAME=${OUT_DATA_DIR}${ZIP_DATA_FILE}.$STATUS.$CUR_DATE
	mv -f ${ZIP_DATA} $INPUT_FILE_NAME
	compressFile
	INPUT_FILE_NAME=${OUT_DATA_DIR}${CLIENT_DATA_FILE}.$STATUS.$CUR_DATE
	mv -f ${CLIENT_DATA} $INPUT_FILE_NAME
	compressFile	
} # end movDataFiles

#===============================================================
#                 FUNCTION DEFINITIONS END HERE
#===============================================================


while getopts :c:C:s:S:hHuU opt
do
    case "$opt" in 
    c|C)
    v_cfv_file=${OPTARG};
	;;
    s|S)
    v_section=${OPTARG};
	;;
    h|H)
	echo $USAGE
	;;
    u|U)
	echo $USAGE
	;;
    :)
	echo "Missing option argument"
	return 1;
	;;
    ?)
	echo "Unknown argument"
	echo $USAGE
	return 1;
	;;
    esac
done

(( shiftCount=OPTIND-1 ))
shift shiftCount

if [[ $# -ne 0 ]] then
    print "Too many arguments"
    return 1;
fi

if [[ -z $v_cfv_file ]] then
    echo "Config file was not provided. It is required." > ${TEMP_LOG}
    logmsg -m "Config file was not provided. It is required." -l $LINENO -t -f;
    mailError
fi

if [[ "${VERBOSE:- N}" = "Y" ]] then
    echo "Using config file ${v_cfv_file}."
fi

#-----------------------------------------------------------------
# Read global parameters first
# Read this program segment's parameters next. 
#  *Note: These values will overlay any values of same-name 
#         variables defined in the global segment
#-----------------------------------------------------------------
getconfig -c $v_cfv_file -p "$vars_reqd" -s global
getconfig -c $v_cfv_file -p "$vars_reqd" -s $v_section



#-----------------------------------------------------------------
# Test Existence of parameters
#-----------------------------------------------------------------
reqdParamTest "$vars_reqd"
exit_stat=$?
if [[ exit_stat -ne 0 ]] then
    return 1;
    exit 1
fi

USAGE="execCommandForRollUp.ksh -c <config file>"
logmsg -m "Beginning processing for $0 " -l $LINENO -p $0 -t 
retCd=0;




# Loop forever

integer CUR_TIME
integer TMP_SLEEP_TIME
TMP_SLEEP_TIME=600

cd $IN_DATA_DIR

# ZIP_DATA=$IN_DATA_DIR`ls -1rt $ZIP_DATA_FILE.?????? | head -1`
# CLIENT_DATA=$IN_DATA_DIR`ls -1rt $CLIENT_DATA_FILE.?????? | head -1`

while [ true ]
do 	
	CUR_TIME=`date +%H%M`
	#--------------------------------------------------------------
	## Check if it's time to start processing
	#--------------------------------------------------------------	
	while (( $CUR_TIME < $PROC_START_TIME ))
	do
		## Validate thats its time to run
		## if not, sleep 
		logmsg -m  "CUR_TIME = $CUR_TIME, PROC_START_TIME = $PROC_START_TIME, PROC_END_TIME = $PROC_END_TIME, SLEEP_TIME = $SLEEP_TIME"
		echo "CUR_TIME = $CUR_TIME, PROC_START_TIME = $PROC_START_TIME, PROC_END_TIME = $PROC_END_TIME, SLEEP_TIME = $SLEEP_TIME"
		
		sleep $TMP_SLEEP_TIME
		CUR_TIME=`date +%H%M`
	done
	
	## Process has executed past the end time, terminate
	if (( $CUR_TIME >= $PROC_END_TIME ))
	then
		logmsg -m  "Current time : $CUR_TIME  is past/at end time : $PROC_END_TIME. Terminating . . ."
		echo "Current time : $CUR_TIME  is past end time : $PROC_END_TIME. Terminating . . ."
		break
	fi

	#--------------------------------------------------------------
	## Get the earliest zip file and the corresponding non-zip file
	#--------------------------------------------------------------	
	EARLIEST_ZIP_FILE=`ls $ZIP_DATA_FILE.?????? | /bin/sort | head -1 | awk '{print $0 }'`
	ZIP_DATA=$IN_DATA_DIR$EARLIEST_ZIP_FILE
        time_suffix=`echo $EARLIEST_ZIP_FILE | awk -F. '{print $3}'`
	CLIENT_DATA=$IN_DATA_DIR$CLIENT_DATA_FILE.$time_suffix	
	
	#--------------------------------------------------------------
	## Check if data files have been provided
	#--------------------------------------------------------------
	until [[ -f ${ZIP_DATA} && -f ${CLIENT_DATA} ]] 
	do
	    sleep $SLEEP_TIME
	    CUR_TIME=`date +%H%M`
            if (( $CUR_TIME >= $PROC_END_TIME ))
            then
		logmsg -m  "Current time : $CUR_TIME  is past/at end time : $PROC_END_TIME. Terminating . . ."
		echo "Current time : $CUR_TIME  is past end time : $PROC_END_TIME. Terminating . . ."
		break 2
	    fi
		EARLIEST_ZIP_FILE=`ls $ZIP_DATA_FILE.?????? | /bin/sort | head -1 | awk '{print $0 }'`
		ZIP_DATA=$IN_DATA_DIR$EARLIEST_ZIP_FILE
		time_suffix=`echo $EARLIEST_ZIP_FILE | awk -F. '{print $3}'`
		CLIENT_DATA=$IN_DATA_DIR$CLIENT_DATA_FILE.$time_suffix		    
	done
	
	CUR_DATE=`date +%d.%h.%y-%H:%M`
		
	>$TEMP_LOG
	>$LOAD_LOG
	>$MAIL_LOG
	

	#--------------------------------------------------------------
	## check if DATA files are not empty
	#--------------------------------------------------------------

	typeset -i zip_line_count=`wc -l < ${ZIP_DATA}`
	typeset -i client_line_count=`wc -l < ${CLIENT_DATA}`

	if [[ ${zip_line_count} -le 1 && ${client_line_count} -le 1 ]] ; then
	    echo "Data files ${ZIP_DATA} and ${CLIENT_DATA} were empty."
	    echo "Data files ${ZIP_DATA} and ${CLIENT_DATA} were found to be empty at $CUR_DATE." > ${TEMP_LOG}
	    
	    mailError	    
	    logmsg -m "Data files ${ZIP_DATA} and ${CLIENT_DATA} were empty at $CUR_DATE." -l $LINENO -p $0;
	    
	    STATUS=FAILED
	    movDataFiles
	    
	else

		#--------------------------------------------------------------
		## check if RESTART_FILE is found and is readable and is 
		## valid for the current data files
		#--------------------------------------------------------------
		integer COMMAND_NO=0
		logmsg -m "Check if RESTART_FILE [$RESTART_FILE] exists." 
		if [[ -r ${RESTART_FILE} ]] then

		    # Check if both the data files are more recent than the restart file
		    OLD_FILE=`ls -1rt $RESTART_FILE $CLIENT_DATA $ZIP_DATA|head -1`

		    # If yes, delete the restart file so that new data files can be processed.
		    if [[ $OLD_FILE = $RESTART_FILE ]] then
			rm -f $RESTART_FILE
			logmsg -m "Data files are newer than restart file. Removed the old restart file." -l $LINENO -p $0 -t
			echo "Data files are newer than restart file. Removed the old restart file."
		    else    
			COMMAND_NO=`cat ${RESTART_FILE}|cut -f1 -d'|'`
			logmsg -m "Restarting processing after step [$COMMAND_NO]" -l $LINENO -p $0 -t 
		    fi
		else
		    COMMAND_NO=0
		    echo "$COMMAND_NO|" > ${RESTART_FILE}
		fi

		logmsg -m "COMMAND_NO from RESTART_FILE is [$COMMAND_NO]" -l $LINENO -p $0 -t
		integer i=0


		trap 'rm -f $RESTART_FILE $TEMP_LOG $LOAD_LOG $MAIL_LOG; exit 1' 1 2 15


		# Execute the command for Rollup
		set -
		while [ $i -lt 5 ]
		do
		    (( i = $i + 1 ))

		    #--------------------------------------------------------------
		    ## all commands for Rollup are here
		    #--------------------------------------------------------------

		    case $i in
			1) command="sqlldr userid=${DISTBATCH_FSA_ORA_USR}/${DISTBATCH_FSA_ORA_PWD}@${DISTBATCH_FSA_ORA_SID} control=$BATCH_BIN_DIR/sql/staged_cm_zip_data_group.ctl log=$LOAD_LOG data=$ZIP_DATA skip=1 errors=0" message="sqlldr userid={DISTBATCH_FSA_ORA_USR}/{DISTBATCH_FSA_ORA_PWD}@${DISTBATCH_FSA_ORA_SID} control=$BATCH_BIN_DIR/sql/staged_cm_zip_data_group.ctl log=$LOAD_LOG data=$ZIP_DATA skip=1 errors=0" ;;
			2) command="sqlldr userid=${DISTBATCH_FSA_ORA_USR}/${DISTBATCH_FSA_ORA_PWD}@${DISTBATCH_FSA_ORA_SID} control=$BATCH_BIN_DIR/sql/staged_cm_client_data_group.ctl log=$LOAD_LOG data=$CLIENT_DATA skip=1 errors=0" message="sqlldr userid={DISTBATCH_FSA_ORA_USR}/{DISTBATCH_FSA_ORA_PWD}@${DISTBATCH_FSA_ORA_SID} control=$BATCH_BIN_DIR/sql/staged_cm_client_data_group.ctl log=$LOAD_LOG data=$CLIENT_DATA skip=1 errors=0" ;;
			3) command="sqlplus ${DISTBATCH_FSA_ORA_USR}/${DISTBATCH_FSA_ORA_PWD}@${DISTBATCH_FSA_ORA_SID} @$BATCH_BIN_DIR/sql/stagedCoverageModelRuleForZip.sql staged_coverage_model_rule staged_cm_zip_data_group $BATCH_LOG_DIR/daily/terrMapRollUpZipReject.log.$CUR_DATE" message="sqlplus {DISTBATCH_FSA_ORA_USR}/{DISTBATCH_FSA_ORA_PWD}@${DISTBATCH_FSA_ORA_SID} @$BATCH_BIN_DIR/sql/stagedCoverageModelRuleForZip.sql staged_coverage_model_rule staged_cm_zip_data_group $BATCH_LOG_DIR/daily/terrMapRollUpZipReject.log.$CUR_DATE" ;;
			4) command="sqlplus ${DISTBATCH_FSA_ORA_USR}/${DISTBATCH_FSA_ORA_PWD}@${DISTBATCH_FSA_ORA_SID} @$BATCH_BIN_DIR/sql/stagedCoverageModelRuleForClient.sql staged_coverage_model_rule staged_cm_client_data_group sales_dstbn_structure_wip $BATCH_LOG_DIR/daily/terrMapRollUpClientReject.log.$CUR_DATE" message="sqlplus {DISTBATCH_FSA_ORA_USR}/{DISTBATCH_FSA_ORA_PWD}@${DISTBATCH_FSA_ORA_SID} @$BATCH_BIN_DIR/sql/stagedCoverageModelRuleForClient.sql staged_coverage_model_rule staged_cm_client_data_group sales_dstbn_structure_wip $BATCH_LOG_DIR/daily/terrMapRollUpClientReject.log.$CUR_DATE" ;;
			5) command="sqlplus ${DISTBATCH_FSA_ORA_USR}/${DISTBATCH_FSA_ORA_PWD}@${DISTBATCH_FSA_ORA_SID} @$BATCH_BIN_DIR/sql/terrMapRollup.sql staged_coverage_model_rule coverage_model_wip coverage_model_rule_wip sds_coverage_model_wip $BATCH_LOG_DIR/daily/terrMapRollup.log.$CUR_DATE" message="sqlplus {DISTBATCH_FSA_ORA_USR}/{DISTBATCH_FSA_ORA_PWD}@${DISTBATCH_FSA_ORA_SID} @$BATCH_BIN_DIR/sql/terrMapRollup.sql staged_coverage_model_rule coverage_model_wip coverage_model_rule_wip sds_coverage_model_wip $BATCH_LOG_DIR/daily/terrMapRollup.log.$CUR_DATE" ;;
			*) command="" ;;
		    esac
			case $i in
			1) command_omit_password="sqlldr userid=${DISTBATCH_FSA_ORA_USR}/********@${DISTBATCH_FSA_ORA_SID} control=$BATCH_BIN_DIR/sql/staged_cm_zip_data_group.ctl log=$LOAD_LOG data=$ZIP_DATA skip=1 errors=0" message="sqlldr userid={DISTBATCH_FSA_ORA_USR}/{DISTBATCH_FSA_ORA_PWD}@${DISTBATCH_FSA_ORA_SID} control=$BATCH_BIN_DIR/sql/staged_cm_zip_data_group.ctl log=$LOAD_LOG data=$ZIP_DATA skip=1 errors=0" ;;
			2) command_omit_password="sqlldr userid=${DISTBATCH_FSA_ORA_USR}/********@${DISTBATCH_FSA_ORA_SID} control=$BATCH_BIN_DIR/sql/staged_cm_client_data_group.ctl log=$LOAD_LOG data=$CLIENT_DATA skip=1 errors=0" message="sqlldr userid={DISTBATCH_FSA_ORA_USR}/{DISTBATCH_FSA_ORA_PWD}@${DISTBATCH_FSA_ORA_SID} control=$BATCH_BIN_DIR/sql/staged_cm_client_data_group.ctl log=$LOAD_LOG data=$CLIENT_DATA skip=1 errors=0" ;;
			3) command_omit_password="sqlplus ${DISTBATCH_FSA_ORA_USR}/********@${DISTBATCH_FSA_ORA_SID} @$BATCH_BIN_DIR/sql/stagedCoverageModelRuleForZip.sql staged_coverage_model_rule staged_cm_zip_data_group $BATCH_LOG_DIR/daily/terrMapRollUpZipReject.log.$CUR_DATE" message="sqlplus {DISTBATCH_FSA_ORA_USR}/{DISTBATCH_FSA_ORA_PWD}@${DISTBATCH_FSA_ORA_SID} @$BATCH_BIN_DIR/sql/stagedCoverageModelRuleForZip.sql staged_coverage_model_rule staged_cm_zip_data_group $BATCH_LOG_DIR/daily/terrMapRollUpZipReject.log.$CUR_DATE" ;;
			4) command_omit_password="sqlplus ${DISTBATCH_FSA_ORA_USR}/********@${DISTBATCH_FSA_ORA_SID} @$BATCH_BIN_DIR/sql/stagedCoverageModelRuleForClient.sql staged_coverage_model_rule staged_cm_client_data_group sales_dstbn_structure_wip $BATCH_LOG_DIR/daily/terrMapRollUpClientReject.log.$CUR_DATE" message="sqlplus {DISTBATCH_FSA_ORA_USR}/{DISTBATCH_FSA_ORA_PWD}@${DISTBATCH_FSA_ORA_SID} @$BATCH_BIN_DIR/sql/stagedCoverageModelRuleForClient.sql staged_coverage_model_rule staged_cm_client_data_group sales_dstbn_structure_wip $BATCH_LOG_DIR/daily/terrMapRollUpClientReject.log.$CUR_DATE" ;;
			5) command_omit_password="sqlplus ${DISTBATCH_FSA_ORA_USR}/********@${DISTBATCH_FSA_ORA_SID} @$BATCH_BIN_DIR/sql/terrMapRollup.sql staged_coverage_model_rule coverage_model_wip coverage_model_rule_wip sds_coverage_model_wip $BATCH_LOG_DIR/daily/terrMapRollup.log.$CUR_DATE" message="sqlplus {DISTBATCH_FSA_ORA_USR}/{DISTBATCH_FSA_ORA_PWD}@${DISTBATCH_FSA_ORA_SID} @$BATCH_BIN_DIR/sql/terrMapRollup.sql staged_coverage_model_rule coverage_model_wip coverage_model_rule_wip sds_coverage_model_wip $BATCH_LOG_DIR/daily/terrMapRollup.log.$CUR_DATE" ;;
			*) command_omit_password="" ;;
		    esac
		    if [[ $i -gt $COMMAND_NO ]] then
			logmsg -m "$0: Step $i - Executing <$command_omit_password> " -l $LINENO -p $0 -t;

			# Build the command with expanded environment variables

			# Execute the command and check the status
			echo $message >${TEMP_LOG}
			: $(eval $command)
			echo $command_omit_password >${MAIL_LOG}


			exit_stat=$?

			if [[ $exit_stat != 0 ]] then
			    logmsg -m "Execution FAILED for Step $i / command: <$command_omit_password> at $CUR_DATE" -l $LINENO -p $0 ;
			    cat ${MAIL_LOG}>>${LOG_FILE}

			    a=`echo $command|cut -c1-6`
			    if [ $a = sqlldr ]
			    then
				cat ${LOAD_LOG}>>${TEMP_LOG}
			    fi	

			    if [ $a = sqlplu ]
			    then
				cat ${MAIL_LOG}>>${TEMP_LOG}
			    fi	

			    mailError

			    rm -f $LOAD_LOG $MAIL_LOG
			    STATUS=FAILED
			    movDataFiles
			    logmsg -m "Processing not completed for Data files at $CUR_DATE " -l $LINENO -p $0 -t 
			    break

			else
			    logmsg -m "Execution SUCCEEDED for Step $i / command: <$command_omit_password> " -l $LINENO -p $0;
			    echo "$i|" > ${RESTART_FILE}
			    cat ${MAIL_LOG}>>${LOG_FILE}
			    
			    # if processing has been done till the last command
			    if [[ $i -eq 5 ]] then
			    	STATUS=PROCESSED
			    fi

			fi
		    fi
		done 
		
		if [[ $STATUS = PROCESSED ]] then
			movDataFiles

			# remove the restart file and other log files
			rm -f $RESTART_FILE $TEMP_LOG $LOAD_LOG $MAIL_LOG

			logmsg -m "Processing completed successfully for Data files at $CUR_DATE " -l $LINENO -p $0 -t 
		fi
	fi
done



logmsg -m "---------------------------------------------------------------------"
logmsg -m "The process has finished successfully." -t -p ${PGM_NM}
logmsg -m "---------------------------------------------------------------------"

return $retCd;


