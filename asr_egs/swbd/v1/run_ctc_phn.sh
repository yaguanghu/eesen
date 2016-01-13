#!/bin/bash

. ./cmd.sh ## You'll want to change cmd.sh to something that will work on your system.
           ## This relates to the queue.
. path.sh

stage=0

# Set paths to various datasets
wav_dir=/home/mobvoi/wav-data/wechat_voice_130h
test_wav_dir=/export/ca/wave-data/test_set/201405_07
dict=/export/ca/expts/yaguang/dict/mandarin_withtone_full_converted.dict
fisher_dirs="/export/ca/LDC/LDC2004T19/fe_03_p1_tran/ /export/ca/LDC/LDC2005T19/fe_03_p2_tran/" # Set to "" if you don't have the fisher corpus
eval2000_dirs="/export/ca/LDC/LDC2002S09/hub5e_00 /export/ca/LDC/LDC2002T43"

# CMU Rocks
#fisher_dirs="/data/ASR5/babel/ymiao/Install/LDC/LDC2004T19/fe_03_p1_tran/ /data/ASR5/babel/ymiao/Install/LDC/LDC2005T19/fe_03_p2_tran/"
#eval2000_dirs="/data/ASR4/babel/ymiao/CTS/LDC2002S09/hub5e_00 /data/ASR4/babel/ymiao/CTS/LDC2002T43"

. parse_options.sh

if [ $stage -le 1 ]; then
  echo =====================================================================
  echo "             Data Preparation and FST Construction                 "
  echo =====================================================================
  # Use the same datap prepatation script from Kaldi
  local/mobvoi_data_prep.sh $wav_dir $dict "train" || exit 1;
  local/mobvoi_data_prep.sh $test_wav_dir $dict "201405_07" || exit 1;

  # Construct the phoneme-based lexicon
  local/mobvoi_prepare_phn_dict.sh $dict || exit 1;

  # Compile the lexicon and token FSTs
  utils/ctc_compile_dict_token.sh data/local/dict_phn data/local/lang_phn_tmp data/lang_phn || exit 1;

  # Train and compile LMs.
  local/swbd1_train_lms.sh data/local/train/text data/local/dict_phn/lexicon.txt data/local/lm || exit 1;

  # Compile the language-model FST and the final decoding graph TLG.fst
  local/swbd1_decode_graph.sh data/lang_phn data/local/dict_phn/lexicon.txt || exit 1;

  # Data preparation for the eval2000 set
  #local/eval2000_data_prep.sh $eval2000_dirs
fi

if [ $stage -le 2 ]; then
  echo =====================================================================
  echo "                    FBank Feature Generation                       "
  echo =====================================================================
  fbankdir=fbank

  # Generate the fbank features; by default 40-dimensional fbanks on each frame
  steps/make_fbank.sh --cmd "$train_cmd" --nj 10 data/train exp/make_fbank/train $fbankdir || exit 1;
  utils/fix_data_dir.sh data/train || exit;
  steps/compute_cmvn_stats.sh data/train exp/make_fbank/train $fbankdir || exit 1;

  #steps/make_fbank.sh --cmd "$train_cmd" --nj 10 data/eval2000 exp/make_fbank/eval2000 $fbankdir || exit 1;
  #utils/fix_data_dir.sh data/eval2000 || exit;
  #steps/compute_cmvn_stats.sh data/eval2000 exp/make_fbank/eval2000 $fbankdir || exit 1;

  # Use the first 4k sentences as dev set, around 5 hours
  utils/subset_data_dir.sh --first data/train 4000 data/train_dev
  n=$[`cat data/train/wav.scp | wc -l` - 4000]
  utils/subset_data_dir.sh --last data/train $n data/train_nodev

  # Create a smaller training set by selecting the first 100k utterances, around 110 hours
  #utils/subset_data_dir.sh --first data/train_nodev 100000 data/train_100k
  #local/remove_dup_utts.sh 200 data/train_100k data/train_100k_nodup

  # Finally the full training set, around 286 hours
  local/remove_dup_utts.sh 300 data/train_nodev data/train_nodup
fi

if [ $stage -le 5 ]; then
  echo =====================================================================
  echo "                  Network Training with the Full Set               "
  echo =====================================================================
  input_feat_dim=120   # dimension of the input features; we will use 40-dimensional fbanks with deltas and double deltas
  lstm_layer_num=4     # number of LSTM layers
  lstm_cell_dim=320    # number of memory cells in every LSTM layer

  dir=exp/train_phn_l${lstm_layer_num}_c${lstm_cell_dim}
  mkdir -p $dir

  target_num=`cat data/lang_phn/units.txt | wc -l`; target_num=$[$target_num+1]; # #targets = #labels + 1 (the blank)

  # Output the network topology
  utils/model_topo.py --input-feat-dim $input_feat_dim --lstm-layer-num $lstm_layer_num \
    --lstm-cell-dim $lstm_cell_dim --target-num $target_num \
    --fgate-bias-init 1.0 > $dir/nnet.proto || exit 1;

  # Label sequences; simply convert words into their label indices
  utils/prep_ctc_trans.py data/lang_phn/lexicon_numbers.txt data/train_nodup/text "<unk>" | gzip -c - > $dir/labels.tr.gz
  utils/prep_ctc_trans.py data/lang_phn/lexicon_numbers.txt data/train_dev/text "<unk>" | gzip -c - > $dir/labels.cv.gz

  # Train the network with CTC. Refer to the script for details about the arguments
  steps/train_ctc_parallel.sh --add-deltas true --num-sequence 20 --frame-num-limit 10000 \
    --learn-rate 0.00004 --report-step 1000 --halving-after-epoch 12 --sort-by-len true\
    data/train_nodup data/train_dev $dir || exit 1;
fi

if [ $stage -le 6 ]; then
  echo =====================================================================
  echo "                            Decoding                               "
  echo =====================================================================
  fbankdir=fbank
  steps/make_fbank.sh --cmd "$train_cmd" --nj 10 data/201405_07 exp/make_fbank/201405_07 $fbankdir || exit 1;
  utils/fix_data_dir.sh data/201405_07 || exit;
  steps/compute_cmvn_stats.sh data/201405_07 exp/make_fbank/201405_07 $fbankdir || exit 1;
  input_feat_dim=120   # dimension of the input features; we will use 40-dimensional fbanks with deltas and double deltas
  lstm_layer_num=4     # number of LSTM layers
  lstm_cell_dim=320    # number of memory cells in every LSTM layer

  dir=exp/train_phn_l${lstm_layer_num}_c${lstm_cell_dim}
  fbankdir=fbank
  #steps/make_fbank.sh --cmd "$train_cmd" --nj 10 data/201405_07 exp/make_fbank/201405_07 $fbankdir || exit 1;
  #utils/fix_data_dir.sh data/201405_07 || exit;
  #steps/compute_cmvn_stats.sh data/201405_07 exp/make_fbank/201405_07 $fbankdir || exit 1;
  # decoding
  for lm_suffix in mobvoi_sm; do
    steps/decode_ctc_lat.sh --cmd "$decode_cmd" --nj 60 --beam 17.0 --lattice_beam 8.0 --max-active 5000 --acwt 0.6 \
      data/lang_phn_${lm_suffix} data/201405_07 $dir/decode_201405_07_${lm_suffix} || exit 1;
  done
fi
