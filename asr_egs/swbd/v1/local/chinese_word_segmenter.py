#!/usr/bin/env python
# Author: eurecq@gmail.com (Qian Chang)
#
# This tool takes a dictionary, an input fild with id and words, and an output filename
# It outputs the id and segmented words

import sys

def Usage():
  print "Usage: %s dict_file input_filename output_filenmae" % (sys.argv[0],)
  sys.exit(-1)
    
if __name__ == '__main__':
  if len(sys.argv) != 4:
    Usage()

  dict = {}
  for line in open(sys.argv[1], 'r'):
    key = line.decode('utf-8').split('\t')[0]
    dict[key] = 1

  fout = open(sys.argv[3], 'w')

  for line in open(sys.argv[2], 'r'):
    sound_id = line.decode('utf-8').split()[0]
    words_list = line.decode('utf-8')[len(sound_id):].split()
    total_word_list = []
    for word in words_list:
      word = word.strip(' \r\n')
      n = len(word)
      pos = 0      
      word_list = []
      while pos < n:
        found = False
        for i in range(n, pos, -1):
          key = word[pos:i]
          if key in dict:
            word_list.append(key)
            pos = i
            found = True
            break
        if not found:
          write_str = "Error: Out of Vocabulary (%s)" % (word[pos:pos+1],)
          print write_str.encode('utf-8')
          sys.exit(-1)
      if len(word_list) == 0:
        word_list.append(word)
      for w in word_list:
        total_word_list.append(w)
        
    write_str = sound_id
    for word in total_word_list:
      write_str += ' ' + word
    write_str += '\n'
    
    fout.write(write_str.encode('utf-8'))
