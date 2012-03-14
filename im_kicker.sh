#!/bin/sh

sem="ln_`basename $0`"
dir=`dirname $0`
ln -s /dummy $sem || exit
trap "rm $sem; exit" 2 3 15



ruby $dir"/im_src/redmine_syncer.rb"



rm "$sem"

exit
