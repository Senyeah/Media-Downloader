#!/bin/bash
# Listens for ffmpeg progress written by ffmpeg -progress and then
# emits desired information back

PROGRESS_PIPE=ffmpeg-progress
[ ! -p $PROGRESS_PIPE ] && mkfifo $PROGRESS_PIPE

while [ -p $PROGRESS_PIPE ]
do
   if read line; then
      PROGRESS_REGEX="out_time_ms=([0-9]+)"
      SPEED_REGEX="speed=(([0-9]+\.?)+)x"

      # Only emit when both properties have been written, i.e. when
      # $ATTRIBUTE_COUNTER mod 2 == 0
      ATTRIBUTE_COUNTER=0

      if [[ $line =~ $PROGRESS_REGEX ]]; then
         PROGRESS_SECONDS=$(echo "scale=3; ${BASH_REMATCH[1]} / 1000000" | bc)
         ((ATTRIBUTE_COUNTER += 1))
      elif [[ $line =~ $SPEED_REGEX ]]; then
         PROGRESS_SPEED="${BASH_REMATCH[1]}"
         ((ATTRIBUTE_COUNTER += 1))
      fi
      
      if [ $((ATTRIBUTE_COUNTER % 2)) -eq 0 ]; then
         # If they aren't both numerical, then don't output anything
         NUMERICAL_REGEX="^[0-9]+([.][0-9]+)?$"
         
         if [[ $PROGRESS_SPEED =~ $NUMERICAL_REGEX ]] &&
            [[ $PROGRESS_SECONDS =~ $NUMERICAL_REGEX ]]; then
            echo "$PROGRESS_SPEED $PROGRESS_SECONDS"      
         fi
      fi      
   fi
done < $PROGRESS_PIPE