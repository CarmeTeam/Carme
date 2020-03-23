#!/bin/bash

# include cluster specific bash functions ------------------------------------------------------------------------------------------
# it is expected that those funktions are stored as bash scripts with a file-ending ".sh" and are stores in local_bash_functions
# NOTE: the path to check for the scripts is the PATH inside the singularity container!
BASH_SCRIPTS=( "$(find "/home/.CarmeScripts/local_bash_functions" -maxdepth 1 -name "*.sh")" ) 
if [[ "${#BASH_SCRIPTS[@]}" -gt 0 ]];then
  for BASH_SCRIPT in $BASH_SCRIPTS;do
    source "${BASH_SCRIPT}"
  done
fi
#-----------------------------------------------------------------------------------------------------------------------------------

# define Tensorflow Version function -----------------------------------------------------------------------------------------------
function CARME_TENSORFLOW_VERSION () {
  TF_VERSION=$(grep "tensorflow-gpu" ${STOREDIR}/conda_base.txt | awk '{ print $2 }')
  echo ${TF_VERSION}
}
#-----------------------------------------------------------------------------------------------------------------------------------


# define PyTorch Version function --------------------------------------------------------------------------------------------------
function CARME_PYTORCH_VERSION () {
  PT_VERSION=$(grep "pytorch" ${STOREDIR}/conda_base.txt | awk '{ print $2 }')
}
#-----------------------------------------------------------------------------------------------------------------------------------


# define CUDA Version function -----------------------------------------------------------------------------------------------------
function CARME_CUDA_VERSION () {
  CUDA_VERSION=$(nvcc --version  | grep release | awk '{print $6}')
  echo ${CUDA_VERSION}
}
#-----------------------------------------------------------------------------------------------------------------------------------


# define CUDNN_VERSION function ----------------------------------------------------------------------------------------------------
function carme_cudnn_version () {
  CUDNN_VERSION=$(cat /opt/cuda/include/cudnn.h | grep "define CUDNN_MAJOR" | awk '{print $3}' | cut -d/ -f1)
  echo ${CUDNN_VERSION}
}
#-----------------------------------------------------------------------------------------------------------------------------------


# redefine mpirun ------------------------------------------------------------------------------------------------------------------
function carme_mpirun () {
  /opt/anaconda3/bin/mpirun -bind-to none -map-by slot -x NCCL_DEBUG=INFO -x LD_LIBRARY_PATH -x HOROVOD_MPI_THREADS_DISABLE=1 -x PATH --mca plm rsh --mca plm_rsh_args "-F ${HOME}/.local/share/carme/tmp-files-${SLURM_JOB_ID}/ssh_${SLURM_JOB_ID}/ssh_config_${SLURM_JOB_ID}" --mca ras simulator --display-map --wdir ~/tmp --mca btl_openib_warn_default_gid_prefix 0 --mca orte_tmpdir_base ~/tmp --tag-output ${@}
}
#-----------------------------------------------------------------------------------------------------------------------------------


# define cancel function -----------------------------------------------------------------------------------------------------------
function carme_canceljob() {
    NUMBERCHECK='^[0-9]+$'
    if ! [[ $1 =~ ${NUMBERCHECK} ]];then
        VALUE=( $(ps ax | grep "$1" | grep -v grep | awk '{ print $1 }') )
        echo "${VALUE[0]}"
        kill ${VALUE[0]}
        VALUE=( $(ps ax | grep "$1" | grep -v grep | awk '{ print $1 }') )
        if [[ ! -z ${VALUE[0]} ]];then
            pgrep -P ${VALUE[0]} | xargs kill -9
            kill -9 ${VALUE[0]}
        fi
                                                                sleep 1
        VALUE=( $(ps ax | grep "$1" | grep -v grep | awk '{ print $1 }') )
        if [[ ! -z ${VALUE[0]} ]];then
            echo "your job cannot be killed, please contact your systemadministrator"
        fi
    else
        pgrep -P $1 | xargs kill
        kill $1
        VALUE=( $(ps ax | grep $1 | grep -v grep | awk '{ print $1 }') )
        if [[ ! -z ${VALUE[0]} ]];then
            pgrep -P $1 | xargs kill -9
            kill -9 $1
        fi
                                                                sleep 1
        VALUE=( $(ps ax | grep "$1" | grep -v grep | awk '{ print $1 }') )
        if [[ ! -z ${VALUE[0]} ]];then
            echo "your job cannot be killed, please contact your systemadministrator"
        fi
    fi
}
#-----------------------------------------------------------------------------------------------------------------------------------


# define compress function ---------------------------------------------------------------------------------------------------------
function carme_archive (){
  parameter_array=($@)
  parameter_array_length=${#parameter_array[@]}
  if [[ "$parameter_array_length" -le "1" ]];then
    if [ "${parameter_array[0]}" == "--help"  ] || [ "${parameter_array[0]}" == "-h" ]; then
      echo "carme-archive creates a compressed tar-file (tar.gz) of"
      echo "the specified folder(s)/file(s) (see USAGE) and after the"
      echo "archive is created deletes the original folder(s)/file(s)."
      echo ""
      echo "USAGE:"
      echo "carme-archive ARCHIVE-NAME FOLDER"
      echo "or"
      echo "carme-archive ARCHIVE-NAME FOLDER-1 FOLDER-2 ..."
      echo "or"
      echo "carme-archive ARCHIVE-NAME FILE-1 FILE-2 FILE3 ..."
    else
      echo "You did not specify an archive name or a folder/files to archive!"
      echo "Use carme-archive --help or carme-archive -h for more information."
    fi
  else
    archive_name="${parameter_array[@]:0:1}"
    archive_files=("${parameter_array[@]:1:$parameter_array_length}")
    
    tar -vczf ${archive_name}.tar.gz ${archive_files[@]} --remove-files
  fi
}
complete -f -d carme_archive
#-----------------------------------------------------------------------------------------------------------------------------------


# define uncompress function -------------------------------------------------------------------------------------------------------
function carme_unarchive (){
  archive_name=$1
  if [[ -z ${archive_name} ]];then
      echo "You did not specify an archive to extract!"
      echo "Use carme-unarchive --help or carme-unarchive -h for more information."
  elif [ "${archive_name}" == "--help"  ] || [ "${archive_name}" == "-h" ]; then
      echo "carme-unarchive extracts a compressed tar-file (tar.gz)"
      echo "in the local folder and then removes the original archive."
      echo ""
      echo "USAGE:"
      echo "carme-unarchive ARCHIVE-NAME.tar.gz"
  else
  
    tar -vxzf ${archive_name}
    
    if [ $? != 0 ];then
      echo "extracting $1 failed"
    else
      rm -v $1
    fi
  fi
}
complete -f carme_unarchive
#-----------------------------------------------------------------------------------------------------------------------------------


# define function to add results to tensorboard ------------------------------------------------------------------------------------
function carme_tensorboard_visualize () {
  parameter_array=($@)
  parameter_array_length=${#parameter_array[@]}
  if [[ "${parameter_array_length}" -gt "1" ]];then
    echo "You can only link one folder, use --help or -h for more information"
  elif [[ "${parameter_array_length}" -le "1" ]];then
    if [ "${parameter_array[0]}" == "--help"  ] || [ "${parameter_array[0]}" == "-h" ]; then
      echo "With carme_tensorboard_visualize you can add previous results to your running tensorboard."
      echo "You should only add the results you need (and not your entire home folder)!! Per default a"
      echo "job starts with an empty tensorboard folder in HOME/tensorboard/tensorboad_JOBID and only"
      echo "this folder is visualized in the running job. Note that this folder is delated on a regular"
      echo "base. Therefore you should use this function to temporarily make your results visible in"
      echo "your running job."
      echo ""
      echo "USAGE:"
      echo "e.g. carme_tensorboard_visualize results/my-results-1"
      echo ""
      echo "NOTE:"
      echo "You can delete such a temporarily visible folder with carme_tensorboard_unvisualize."
    else
      dir_name=${parameter_array[0]}
      full_dir_name=$(realpath $dir_name)
      link_name=$(realpath ${dir_name} | sed 's/.*\///')
      ln -s ${full_dir_name} ${HOME}/tensorboard/tensorboard_${SLURM_JOB_ID}/${link_name}
      echo "added ${link_name} to tensorboard"
    fi
  fi
}
complete -d carme_tensorboard_visualize
#-----------------------------------------------------------------------------------------------------------------------------------


# define function to remove results to tensorboard ---------------------------------------------------------------------------------
function carme_tensorboard_unvisualize () {
  parameter_array=($@)
  parameter_array_length=${#parameter_array[@]}
  if [[ "${parameter_array_length}" -gt "1" ]];then
    echo "You can only remove one link, use --help or -h for more information"
  elif [[ "${parameter_array_length}" -le "1" ]];then
    if [ "${parameter_array[0]}" == "--help"  ] || [ "${parameter_array[0]}" == "-h" ]; then
      echo "With carme_tensorboard_unvisualize you can remove results so that they are no longer"
      echo "visible within tensorboard in your runinng job."
      echo ""
      echo "USAGE:"
      echo "e.g. carme_tensorboard_unvisualize tensorboard/tensorboard_JOBID/my-results"
    else
      dir_name=${parameter_array[0]}
      full_dir_name=$(realpath $dir_name)
      link_name=$(realpath ${dir_name} | sed 's/.*\///')
      rm ${HOME}/tensorboard/tensorboard_${SLURM_JOB_ID}/${link_name}
      echo "removed ${link_name} from tensorboard"
    fi
  fi
}
complete -f -d carme_tensorboard_unvisualize
#-----------------------------------------------------------------------------------------------------------------------------------


# define function to see the results added to tensorboard --------------------------------------------------------------------------
function carme_tensorboard_ls () {
  if [ "$1" == "--help"  ] || [ "$1" == "-h" ];then
    echo "With carme_tensorboard_ls you can see which folders"
    echo "are linked to your current tensorboard job-folder."
    echo ""
    echo "USAGE:"
    echo "carme_tensorboard_ls"
  elif [ -z "$1" ];then
    ls -lah ${HOME}/tensorboard/tensorboard_${SLURM_JOB_ID}
  else
    echo "Use --help or -h to get more information."
  fi
}
#-----------------------------------------------------------------------------------------------------------------------------------

