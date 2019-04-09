#!/bin/bash

# Arguments:
#   $1: Media directory (output from youtube-dl)
#   $2-$n: Files inside $1 to transcode

exec &> transcode.log

# Random ASCII name for the droplet
#DROPLET_NAME=$(uuidgen | shasum | awk '{print $1}')
DROPLET_NAME='transcode-droplet'

# Create new DigitalOcean compute droplet...
#
# (Eventually when DigitalOcean switches to per-second rather
# than per-hour pricing I'll be able to use c-32 for max speed)
#
# Benchmark times:
#   c-16 22m: 5m 20s (~5.5x) ~$0.5/hr
#   c-32 22m: 5m 10s (~6.7x) ~$1/hr
doctl compute droplet create "$DROPLET_NAME" \
      --size c-8 \
      --image 45740183 \
      --region lon1 \
      --ssh-keys 23354048

# Its associated ID is needed for certain doctl commands
DROPLET_ID=$(
  doctl compute droplet list "$DROPLET_NAME" \
      --output json | jq -r '.[0].id'
)

echo "Got $DROPLET_ID from DigitalOcean"

# Get the IP address of the newly-created droplet
SERVER_ADDRESS='null'

# Wait for the server to actually have an IP address
while [ $SERVER_ADDRESS = 'null' ]
do
  sleep 0.5
  SERVER_ADDRESS=$(
    doctl compute droplet get $DROPLET_ID --output json | \
    jq -r '.[0].networks.v4[0].ip_address'
  )
done

echo "Server address is $SERVER_ADDRESS"

# Get the public key of the new server
ssh-keyscan -H $SERVER_ADDRESS >> ~/.ssh/known_hosts

# Stop strict host key checking for the droplet
ssh -o 'StrictHostKeyChecking no' root@$SERVER_ADDRESS ':'

# echo "Copying binaries..."
# Quickest method to get binaries across to the transcoding server
# scp ~/bin/ffmpeg ~/bin/ffprobe root@$SERVER_ADDRESS:/usr/bin

# Copy media and hls creation script
scp ~/create-hls-stream.sh ~/ffmpeg-monitor-progress.sh root@$SERVER_ADDRESS:~

echo "Finished copying binaries"

# Files used in the transcoding process
STATUS_FILE="$1/status.json"
TRANSCODE_PROGRESS_PIPE=transcode-progress

# Ensure the droplet is always deleted no matter the script result
# (shit's too damn expensive lolz) and remove the lockfiles
cleanup() {
  [ -e $STATUS_FILE.lock ] && rm $STATUS_FILE.lock
  [ -p $TRANSCODE_PROGRESS_PIPE ] && rm $TRANSCODE_PROGRESS_PIPE
  doctl compute droplet delete -f $DROPLET_ID
}

trap cleanup EXIT HUP INT QUIT TERM

# Appends a given key–value pair to the given
# object located inside $STATUS_FILE
#
# Arguments:
#  $1 -> URL of object to update
#  $2 -> Key of object
#  $3 -> Value of object as a JSON literal
#
# Example:
#   update_status_field <url> "duration" 1200
update_status_field() {
  # Ensure the literal is valid before committing an update
  jq empty <<< "$3" && \
  flock $STATUS_FILE.lock \
  jq --arg url "$1" \
    --arg key "$2" \
    --argjson val "$3" \
    '.downloaded |= map(
      if .url == $url then
        . += {($key): $val}
      else . end
    )' $STATUS_FILE | \
  sponge $STATUS_FILE
}

# Updates status.json with progress from ffmpeg
# Arguments:
#  $1 -> downloaded URL
#  $2 -> media duration in seconds
update_progress() {
  while [ -p $TRANSCODE_PROGRESS_PIPE ]
  do
    if read line; then
      # Progress lines are written back in the form
      # <SPEED> <SECONDS>
      read PROGRESS_SPEED PROGRESS_SECONDS <<< "$line"
      
      PER_CENT_COMPLETE=$(
        bc <<< "scale=3; $PROGRESS_SECONDS / $2"
      )
      
      TIME_REMAINING=$(
        bc <<< "($2 - $PROGRESS_SECONDS) / $PROGRESS_SPEED"
      )
      
      update_status_field $1 'encode_remaining_sec' $TIME_REMAINING
      update_status_field $1 'encode_progress' $PER_CENT_COMPLETE
    fi
  done < $TRANSCODE_PROGRESS_PIPE
}

mkfifo $TRANSCODE_PROGRESS_PIPE
ssh root@$SERVER_ADDRESS '~/ffmpeg-monitor-progress.sh' &>$TRANSCODE_PROGRESS_PIPE &

# Copy each file, transcode and copy back
for file in "${@:2}"
do
  DOWNLOADED_URL=$(
    jq -r --arg name "$file" \
    '.downloaded[] | select(.download_name == $name) | .url' \
    $STATUS_FILE
  )
  
  VIDEO_DURATION=$(
    ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$1/$file"
  )
  
  update_progress $DOWNLOADED_URL "$VIDEO_DURATION" &
  
  echo "Copying file $1/$file to root@$SERVER_ADDRESS:~/raw-$file"
  scp "$1/$file" root@$SERVER_ADDRESS:~/"raw-$file"
  
  # Spawn a separate process on the server to read the progress
  # of ffmpeg, which is piped to ~/ffmpeg-progress and then read by
  # ~/progress.sh, which emits its contents back to us 
  
  echo "Running ffmpeg..."
  ssh root@$SERVER_ADDRESS "~/create-hls-stream.sh 'raw-$file' '$file-hls'" &>/dev/null
  
  echo "Copying file back..."
  scp -r root@$SERVER_ADDRESS:~/"$file-hls" $1
  
  # Update the status file
  PLAYBACK_URL="http://senyeah.xyz:62987/$file-hls/playlist.m3u8"
  
  flock $STATUS_FILE.lock \
  jq --arg url "$DOWNLOADED_URL" \
    --arg name "$file" \
    --arg playback_url "$PLAYBACK_URL" \
    '.completed |= . + [{
      download_name: $name,
      origin_url: $url,
      playback_url: $playback_url
    }]' $STATUS_FILE | \
  sponge $STATUS_FILE
  
  flock $STATUS_FILE.lock \
  jq --arg name "$file" \
    'del(.downloaded[] | select(.download_name == $name))' \
    $STATUS_FILE | \
  sponge $STATUS_FILE
  
  echo "Transcode of $file complete"
done

# Delete original media
for file in "${@:2}"
do
  rm "$1/$file"
done
