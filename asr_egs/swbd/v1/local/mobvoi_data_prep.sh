#!/bin/bash

# Switchboard-1 training data preparation customized for Edinburgh
# Author:  Arnab Ghoshal (Jan 2013)

# To be run from one directory above this script.

## The input is some directory containing the switchboard-1 release 2
## corpus (LDC97S62).  Note: we don't make many assumptions about how
## you unpacked this.  We are just doing a "find" command to locate
## the .sph files.

## The second input is optional, which should point to a directory containing
## Switchboard transcriptions/documentations (specifically, the conv.tab file).
## If specified, the script will try to use the actual speaker PINs provided 
## with the corpus instead of the conversation side ID (Kaldi default). We 
## will be using "find" to locate this file so we don't make any assumptions
## on the directory structure. (Peng Qi, Aug 2014)

. path.sh

#check existing directories
if [ $# != 4 ]; then
  echo "Usage: mobvoi_data_prep_edin.sh /path/to/SWBD TASK"
  exit 1;
fi

MOBVOI_WAVE_DIR=$1
MOBVOI_DICT=$2
EXPT_DIR=$3
TASK=$4

dir=$EXPT_DIR/data/local/$TASK
mkdir -p $dir


# Audio data directory check
if [ ! -d $MOBVOI_WAVE_DIR ]; then
  echo "Error: run.sh requires a directory argument"
  exit 1;
fi

[ ! -d $MOBVOI_WAVE_DIR ] && \
  echo  "mobvoi wave dir does not exist" &&  exit 1;

[ ! -f $MOBVOI_DICT ] && \
  echo  "mobvoi dictionary file does not exist" &&  exit 1;

local/chinese_word_segmenter.py $MOBVOI_DICT $MOBVOI_WAVE_DIR/text \
  $dir/text || exit 1
cp $MOBVOI_WAVE_DIR/wav.scp  $dir/wav.scp
awk '{print $1 " " "global"}' $dir/wav.scp > $dir/utt2spk
awk 'BEGIN{ORS=" ";printf("global ")}{print $1}END{printf("\n")}' $dir/wav.scp > $dir/spk2utt

# We assume each conversation side is a separate speaker. This is a very 
# reasonable assumption for Switchboard. The actual speaker info file is at:
# http://www.ldc.upenn.edu/Catalog/desc/addenda/swb-multi-annot.summary

# Copy stuff into its final locations [this has been moved from the format_data
# script]
mkdir -p $EXPT_DIR/data/$TASK
for f in spk2utt utt2spk wav.scp text; do
  cp $EXPT_DIR/data/local/$TASK/$f $EXPT_DIR/data/$TASK/$f || exit 1;
done

echo mobvoi data preparation succeeded.

utils/fix_data_dir.sh $EXPT_DIR/data/$TASK
