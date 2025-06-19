FROM sriggi/sclassifier-vit:latest
MAINTAINER Simone Riggi "simone.riggi@gmail.com"

######################################
##   DEFINE CUSTOMIZABLE ARGS/ENVS
######################################
ARG USER_ARG=caesar
ENV USER $USER_ARG

ARG CHANGE_RUNUSER_ARG=1
ENV CHANGE_RUNUSER $CHANGE_RUNUSER_ARG

# - CAESAR OPTIONS
ARG JOB_OPTIONS_ARG=""
ENV JOB_OPTIONS $JOB_OPTIONS_ARG

ARG INPUTFILE_ARG=""
ENV INPUTFILE $INPUTFILE_ARG

ARG JOB_DIR_ARG=""
ENV JOB_DIR $JOB_DIR_ARG

ARG JOB_OUTDIR_ARG=""
ENV JOB_OUTDIR $JOB_OUTDIR_ARG

# - RCLONE OPTIONS
ARG MOUNT_RCLONE_VOLUME_ARG=0
ENV MOUNT_RCLONE_VOLUME $MOUNT_RCLONE_VOLUME_ARG

ARG MOUNT_VOLUME_PATH_ARG="/mnt/storage"
ENV MOUNT_VOLUME_PATH $MOUNT_VOLUME_PATH_ARG

ARG RCLONE_REMOTE_STORAGE_ARG="neanias-nextcloud"
ENV RCLONE_REMOTE_STORAGE $RCLONE_REMOTE_STORAGE_ARG

ARG RCLONE_REMOTE_STORAGE_PATH_ARG="."
ENV RCLONE_REMOTE_STORAGE_PATH $RCLONE_REMOTE_STORAGE_PATH_ARG

ARG RCLONE_MOUNT_WAIT_TIME_ARG=10
ENV RCLONE_MOUNT_WAIT_TIME $RCLONE_MOUNT_WAIT_TIME_ARG

ARG RCLONE_COPY_WAIT_TIME_ARG=30
ENV RCLONE_COPY_WAIT_TIME $RCLONE_COPY_WAIT_TIME_ARG

ENV PYTHONPATH=/usr/lib/python3.8/site-packages/


######################################
##     RUN
######################################
# - Copy models
COPY models/ ${MODEL_DIR}

# - Copy run script
COPY run_job.sh /home/$USER/run_job.sh
RUN chmod +x /home/$USER/run_job.sh

COPY run_classifier.sh /home/$USER/run_classifier.sh
RUN chmod +x /home/$USER/run_classifier.sh

# - Add dir to PATH
ENV PATH ${PATH}:/home/$USER

# - Run container
CMD ["sh","-c","/home/$USER/run_job.sh --runuser=$USER --change-runuser=$CHANGE_RUNUSER --jobargs=\"$JOB_OPTIONS\" --inputfile=$INPUTFILE --jobdir=$JOB_DIR --joboutdir=$JOB_OUTDIR --mount-rclone-volume=$MOUNT_RCLONE_VOLUME --mount-volume-path=$MOUNT_VOLUME_PATH --rclone-remote-storage=$RCLONE_REMOTE_STORAGE --rclone-remote-storage-path=$RCLONE_REMOTE_STORAGE_PATH --rclone-mount-wait=$RCLONE_MOUNT_WAIT_TIME --rclone-copy-wait=$RCLONE_COPY_WAIT_TIME"]

