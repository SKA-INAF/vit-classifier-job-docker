#!/bin/bash -e

# NB: -e makes script to fail if internal script fails (for example when --run is enabled)

#######################################
##         CHECK ARGS
#######################################
NARGS="$#"
echo "INFO: NARGS= $NARGS"

if [ "$NARGS" -lt 1 ]; then
	echo "ERROR: Invalid number of arguments...see script usage!"
  echo ""
	echo "**************************"
  echo "***     USAGE          ***"
	echo "**************************"
 	echo "$0 [ARGS]"
	echo ""
	echo "=========================="
	echo "==    ARGUMENT LIST     =="
	echo "=========================="
	echo "*** MANDATORY ARGS ***"
	echo "--inputfile=[FILENAME] - Input image (FITS/PNG). Takes precedence over --datalist."
	echo "--datalist=[FILENAME] - Input filename (.json) containing images to be processed."
	
	echo ""

	echo "*** OPTIONAL ARGS ***"
	echo "=== MODEL OPTIONS ==="
	echo "--model=[MODEL] - Classifier model to be used in prediction. Options are {smorphclass_multilabel}. Default: smorphclass_multilabel"
	echo ""
	
	echo "=== PRE-PROCESSING OPTIONS ==="
	#echo "--resize - Resize input image before model processor. If false the model processor will resize anyway to its image size "
	#echo "--imgsize=[IMGSIZE] - Size in pixels used for image resize"
	echo "--zscale - Apply zscale transform to each image channel"
	echo "--zscale-contrast=[CONTRAST] - zscale transform contrast parameters (default=0.25)"
	#echo "--grayscale - Load input images in grayscale (1 chan tensor)"
	echo "--norm-min=[NORM_MIN] - MinMax normalization min value (default=0.0)"
	echo "--norm-max=[NORM_MAX] - MinMax normalization max value (default=1.0)"
	
	echo ""
	
	echo "=== RUN OPTIONS ==="
	echo "--run - Run the generated run script on the local shell. If disabled only run script will be generated for later run."	
	echo "--scriptdir=[SCRIPT_DIR] - Job directory where to find scripts (default=/usr/bin)"
	echo "--modeldir=[MODEL_DIR] - Job directory where to find model & weight files (default=/opt/models)"
	echo "--jobdir=[JOB_DIR] - Job directory where to run (default=pwd)"
	echo "--outdir=[OUTPUT_DIR] - Output directory where to put run output file (default=pwd)"
	echo "--waitcopy - Wait a bit after copying output files to output dir (default=no)"
	echo "--copywaittime=[COPY_WAIT_TIME] - Time to wait after copying output files (default=30)"
	echo "--no-logredir - Do not redirect logs to output file in script "	
	echo "--save-base-path - Save base file paths in output file "	
	echo "=========================="
  exit 1
fi


#######################################
##         PARSE ARGS
#######################################
JOB_DIR=""
JOB_OUTDIR=""
#SCRIPT_DIR="/usr/bin"
SCRIPT_DIR="/opt/conda/bin"
MODEL_DIR="/opt/models"

INPUTFILE=""
INPUTFILE_GIVEN=false
DATALIST=""
DATALIST_GIVEN=false

RUN_SCRIPT=false
WAIT_COPY=false
COPY_WAIT_TIME=30
REDIRECT_LOGS=true
SAVE_BASE_PATH_OPT=""

MODEL="smorphclass_multilabel"

#IMGSIZE=224
#RESIZE=""
ZSCALE_STRETCH=""
ZSCALE_CONTRAST="0.25"
NORM_MIN=0
NORM_MAX=1

for item in "$@"
do
	case $item in 
		## MANDATORY ##	
    --inputfile=*)
    	INPUTFILE=`echo $item | /bin/sed 's/[-a-zA-Z0-9]*=//'`		
			if [ "$INPUTFILE" != "" ]; then
				INPUTFILE_GIVEN=true
			fi
    ;;
    --datalist=*)
    	DATALIST=`echo $item | /bin/sed 's/[-a-zA-Z0-9]*=//'`		
			if [ "$DATALIST" != "" ]; then
				DATALIST_GIVEN=true
			fi
    ;;
    
    ## OPTIONAL ##
    --run*)
    	RUN_SCRIPT=true
    ;;
    --scriptdir=*)
    	SCRIPT_DIR=`echo $item | /bin/sed 's/[-a-zA-Z0-9]*=//'`
    ;;
    --modeldir=*)
    	MODEL_DIR=`echo $item | /bin/sed 's/[-a-zA-Z0-9]*=//'`
    ;;
    --outdir=*)
    	JOB_OUTDIR=`echo $item | /bin/sed 's/[-a-zA-Z0-9]*=//'`
    ;;
		--waitcopy*)
    	WAIT_COPY=true
    ;;
		--copywaittime=*)
    	COPY_WAIT_TIME=`echo $item | /bin/sed 's/[-a-zA-Z0-9]*=//'`
    ;;
    --jobdir=*)
    	JOB_DIR=`echo $item | /bin/sed 's/[-a-zA-Z0-9]*=//'`
    ;;
    --no-logredir*)
			REDIRECT_LOGS=false
		;;
    --save-base-path*)
			SAVE_BASE_PATH_OPT="--save_base_path"
		;;
    --model=*)
    	MODEL=`echo $item | sed 's/[-a-zA-Z0-9]*=//'`
    ;;
    
		--zscale*)
    	ZSCALE_STRETCH="--zscale"
    ;;
		--zscale-contrast*)
    	ZSCALE_CONTRAST=`echo $item | sed 's/[-a-zA-Z0-9]*=//'`
    ;;
		--norm-min=*)
    	NORM_MIN=`echo $item | /bin/sed 's/[-a-zA-Z0-9]*=//'`
    ;;
    --norm-max=*)
    	NORM_MAX=`echo $item | /bin/sed 's/[-a-zA-Z0-9]*=//'`
    ;;
    
    *)
    # Unknown option
    echo "ERROR: Unknown option ($item)...exit!"
    exit 1
    ;;
	esac
done


## Check arguments parsed
if [ "$DATALIST_GIVEN" = false ] && [ "$INPUTFILE_GIVEN" = false ]; then
  echo "ERROR: Missing or empty DATALIST & INPUTFILE args (hint: you must specify at least one)!"
  exit 1
fi

if [ "$JOB_DIR" = "" ]; then
  echo "WARN: Empty JOB_DIR given, setting it to pwd ($PWD) ..."
	JOB_DIR="$PWD"
fi

if [ "$JOB_OUTDIR" = "" ]; then
  echo "WARN: Empty JOB_OUTDIR given, setting it to pwd ($PWD) ..."
	JOB_OUTDIR="$PWD"
fi



#######################################
##   SET CLASSIFIER OPTIONS
#######################################
PREPROC_OPTS="$ZSCALE_STRETCH --zscale_contrast=$ZSCALE_CONTRAST --norm_min=$NORM_MIN --norm_max=$NORM_MAX "

if [ "$MODEL" = "smorphclass_multilabel" ]; then
	MODELFILE="$MODEL_DIR/smorphclass_multilabel/siglip-large-patch16-256"
	CLASS_OPTS="--multilabel --label_schema=morph_tags --skip_first_class "

elif [ "$MODEL" = "smorphclass_singlelabel_rgz" ]; then
	MODELFILE="$MODEL_DIR/smorphclass_singlelabel_rgz/siglip-large-patch16-256"
	CLASS_OPTS="--label_schema=morph_class "

elif [ "$MODEL" = "smorphclass_singlelabel_lotss" ]; then
	MODELFILE="$MODEL_DIR/smorphclass_singlelabel_lotss-dr2-horton/resnet18"
	CLASS_OPTS="--label_schema=rg_morph "
	
elif [ "$MODEL" = "anomalyclass_singlelabel" ]; then
	MODELFILE="$MODEL_DIR/models/anomalyclass_singlelabel/siglip-so400m-patch14-384"
	CLASS_OPTS="--label_schema=anomaly_class "
	
else 
	echo "ERROR: Unknown/not supported MODEL argument $MODEL given!"
  exit 1
fi

RUN_OPTS="--report_to=none "

#######################################
##   DEFINE GENERATE EXE SCRIPT FCN
#######################################
# - Set shfile
shfile="run_predict.sh"

# - Set log file
logfile="out.log"

generate_exec_script(){

	local shfile=$1
	
	
	echo "INFO: Creating sh file $shfile ..."
	( 
			echo "#!/bin/bash -e"
			
      echo " "
      echo " "

      echo 'echo "*************************************************"'
      echo 'echo "****         PREPARE JOB                     ****"'
      echo 'echo "*************************************************"'

      echo " "
       
      echo "echo \"INFO: Entering job dir $JOB_DIR ...\""
      echo "cd $JOB_DIR"

			echo " "

      echo 'echo "*************************************************"'
      echo 'echo "****         RUN CLASSIFIER                  ****"'
      echo 'echo "*************************************************"'
				
			EXE="python $SCRIPT_DIR/run.py" 
			ARGS="--predict --inputfile=$INPUTFILE --datalist=$DATALIST $PREPROC_OPTS --modelfile=$MODELFILE $CLASS_OPTS $SAVE_BASE_PATH_OPT $RUN_OPTS "
			CMD="$EXE $ARGS"

			echo "date"
			echo ""
		
			echo "echo \"INFO: Running classifier ...\""
			
			if [ $REDIRECT_LOGS = true ]; then			
      	echo "$CMD >> $logfile 2>&1"
			else
				echo "$CMD"
      fi
      
			echo " "

			echo 'JOB_STATUS=$?'
			echo 'echo "Classifier terminated with status=$JOB_STATUS"'

			echo "date"

			echo " "

      echo 'echo "*************************************************"'
      echo 'echo "****         COPY DATA TO OUTDIR             ****"'
      echo 'echo "*************************************************"'
      echo 'echo ""'
			
			if [ "$JOB_DIR" != "$JOB_OUTDIR" ]; then
				echo "echo \"INFO: Copying job outputs in $JOB_OUTDIR ...\""
				echo "ls -ltr $JOB_DIR"
				echo " "

				echo "# - Copy output data"
				echo 'tab_count=`ls -1 *.dat 2>/dev/null | wc -l`'
				echo 'if [ $tab_count != 0 ] ; then'
				echo "  echo \"INFO: Copying output table file(s) to $JOB_OUTDIR ...\""
				echo "  cp *.dat $JOB_OUTDIR"
				echo "fi"

				echo " "
				
				echo 'tab_count=`ls -1 *.json 2>/dev/null | wc -l`'
				echo 'if [ $tab_count != 0 ] ; then'
				echo "  echo \"INFO: Copying output json file(s) to $JOB_OUTDIR ...\""
				echo "  cp *.json $JOB_OUTDIR"
				echo "fi"
				
				echo " "
				
				echo 'tab_count=`ls -1 *.log 2>/dev/null | wc -l`'
				echo 'if [ $tab_count != 0 ] ; then'
				echo "  echo \"INFO: Copying output log file(s) to $JOB_OUTDIR ...\""
				echo "  cp *.log $JOB_OUTDIR"
				echo "fi"
				
				echo " "
		
				echo "# - Show output directory"
				echo "echo \"INFO: Show files in $JOB_OUTDIR ...\""
				echo "ls -ltr $JOB_OUTDIR"

				echo " "

				echo "# - Wait a bit after copying data"
				echo "#   NB: Needed if using rclone inside a container, otherwise nothing is copied"
				if [ $WAIT_COPY = true ]; then
           echo "sleep $COPY_WAIT_TIME"
        fi
	
			fi

      echo " "
      echo " "
      
      echo 'echo "*** END RUN ***"'

			echo 'exit $JOB_STATUS'

 	) > $shfile

	chmod +x $shfile
}
## close function generate_exec_script()

###############################
##    RUN CLASSIFIER
###############################
# - Check if job directory exists
if [ ! -d "$JOB_DIR" ] ; then 
  echo "INFO: Job dir $JOB_DIR not existing, creating it now ..."
	mkdir -p "$JOB_DIR" 
fi

# - Moving to job directory
echo "INFO: Moving to job directory $JOB_DIR ..."
cd $JOB_DIR

# - Generate run script
echo "INFO: Creating run script file $shfile ..."
generate_exec_script "$shfile"

# - Launch run script
if [ "$RUN_SCRIPT" = true ] ; then
	echo "INFO: Running script $shfile to local shell system ..."
	$JOB_DIR/$shfile
fi


echo "*** END SUBMISSION ***"

