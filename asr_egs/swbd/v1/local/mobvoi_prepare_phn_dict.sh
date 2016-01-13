#!/bin/bash

# This script prepares the phoneme-based lexicon. It also generates the list of lexicon units
# and represents the lexicon using the indices of the units. 

srcdict=$1
expt_dir=$2

srcdir=$expt_dir/data/local/train
dir=$expt_dir/data/local/dict_phn
mkdir -p $dir

[ -f path.sh ] && . ./path.sh

[ ! -f "$srcdict" ] && echo "No such file $srcdict" && exit 1;

# Raw dictionary preparation (lower-case, remove comments)
awk 'BEGIN{getline}($0 !~ /^#/) {$2=tolower($2);print}' \
  $srcdict | sort | awk '($0 !~ /^[[:space:]]*$/) {print}' | \
  perl -e 'while(<>){ chop; $_=~ s/ +/ /; $_=~ s/\s*$//; print "$_\n";}' \
   > $dir/lexicon1.txt || exit 1;

#awk -F'\t' '{print $1 " " $2}' $dir/lexicon1.txt > $dir/lexicon2.txt

cp $dir/lexicon1.txt $dir/lexicon2.txt

# Get the set of lexicon units without noises
cut -d' ' -f2- $dir/lexicon2.txt | tr ' ' '\n' | sort -u > $dir/units_nosil.txt
( echo '!sil sil';  echo '<unk> spn' ) \
  | cat - $dir/lexicon2.txt | sort | uniq > $dir/lexicon3.txt || exit 1

local/swbd1_map_words.pl -f 1 $dir/lexicon3.txt | sort -u > $dir/lexicon.txt || exit 1;

# The complete set of lexicon units, indexed by numbers starting from 1
(echo 'spn'; echo 'sil';) | cat - $dir/units_nosil.txt | awk '{print $1 " " NR}' > $dir/units.txt

# Convert phoneme sequences into the corresponding sequences of units indices, encoded by units.txt
utils/sym2int.pl -f 2- $dir/units.txt < $dir/lexicon.txt > $dir/lexicon_numbers.txt

echo "Phoneme-based dictionary preparation succeeded"
