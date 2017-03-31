#!/bin/bash
DIR="$( dirname $0 )"
for stage in $DIR/kickstart/*.sh; do
  echo "Executing stage: `basename $stage`"
  /bin/bash $stage
done
