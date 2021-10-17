#!/bin/bash

types=(Anime Amv Abooks Books Ebooks Music Video)
disk=$(basename "$1")

for i in ${types[*]}; do
  lc=`echo $i | tr '[:upper:]' '[:lower:]'`
  echo ./disk2yaml.rb "$i/${disk}.yml" "$1" $lc
  ./disk2yaml.rb "$i/${disk}.yml" "$1" $lc
done

