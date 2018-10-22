#!/bin/bash

# Arguments:
#   $1: Media directory (output from youtube-dl)
#   $2-$n: Files inside $1 to transcode

exec &> transcode.log
echo "Beginning transcode"

# Random ASCII name for the droplet
DROPLET_NAME=$(uuidgen | shasum | awk '{print $1}')

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
      --image ubuntu-16-04-x64 \
      --region lon1 \
      --ssh-keys 23354048

# Its associated ID is needed for certain doctl commands
DROPLET_ID=$(
   doctl compute droplet list "$DROPLET_NAME" \
         --output json | jq -r '.[0].id'
)

# Get the IP address of the newly-created droplet
echo "Attempting to obtain droplet IP address..."
SERVER_ADDRESS='null'

# Wait for the server to actually have an IP address
while [ $SERVER_ADDRESS = 'null' ]
do
   sleep 0.5
   SERVER_ADDRESS=$(
      doctl compute droplet get $DROPLET_ID --output json | \
      jq -r '.[0].networks.v4[0].ip_address'
   )
   echo "Got $SERVER_ADDRESS from doctl"
done

echo "IP address is $SERVER_ADDRESS"
echo "Waiting for sshd to init... "

# Get the public key of the new server
ssh-keyscan -H $SERVER_ADDRESS >> ~/.ssh/known_hosts

# Stop strict host key checking for the droplet (‘:’ means do nothing)
ssh -N -o "StrictHostKeyChecking no" root@$SERVER_ADDRESS

echo "Copying binaries to remote..."

# Quickest method to get binaries across to the transcoding server
scp /usr/bin/ffmpeg /usr/bin/ffprobe /usr/bin/bc root@$SERVER_ADDRESS:/usr/bin

# Copy media and hls creation script
scp ~/create-hls-stream.sh ~/ffmpeg-monitor-progress.sh root@$SERVER_ADDRESS:~

STATUS_FILE="$1/status.json"

# Ensure the droplet is always deleted no matter the script result
# (shit's too damn expensive lolz) and remove the lockfiles
cleanup() {
   echo "Trapped exit signal!"
   
   if [ -e $STATUS_FILE.lock ]
   then
      echo "Removing lock file..."
      rm $STATUS_FILE.lock
   fi
   
   echo "Removing ssh pipe..."
   unlink transcode-progress
   
   echo "Removing droplet '$DROPLET_NAME'"
   doctl compute droplet delete -f $DROPLET_NAME
}

trap cleanup EXIT HUP INT QUIT TERM

#
# Appends a given key–value pair to the given
# object located inside $STATUS_FILE
#
# Example:
#   update_status_field <url> "duration" 1200
update_status_field() {
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

update_progress() {
   while true
   do
      if read line < transcode-progress; then
         # Progress lines are written back in the form
         # <SPEED> <SECONDS>
         SPEED=$(echo "$line" | awk '{print $1}')
         SECONDS=$(echo "$line" | awk '{print $2}')
         
         echo "Read '$line' from ffmpeg-progress"
         echo "$line" >> progress.txt
      fi
   done
}

echo "Initialising ffmpeg monitor script"

mkfifo transcode-progress
ssh root@$SERVER_ADDRESS '~/ffmpeg-monitor-progress.sh' &

# Copy each file, transcode and copy back
for file in "${@:2}"
do
   DOWNLOADED_URL=$(
      jq -r --arg name "$file" \
      '.downloaded[] | select(.download_name == $name) | .url' \
      $STATUS_FILE
   )
   
   update_progress $DOWNLOADED_URL &
   
   echo "Copying $1/$file to raw-$file..."
   scp "$1/$file" root@$SERVER_ADDRESS:~/"raw-$file"
   
   echo "Running ffmpeg on 'raw-$file', output to '$file-hls'"
   
   # Spawn a separate process on the server to read the progress
   # of ffmpeg, which is piped to ~/ffmpeg-progress and then read by
   # ~/progress.sh, which emits its contents back to us 
   
   ssh root@$SERVER_ADDRESS "~/create-hls-stream.sh 'raw-$file' '$file-hls'" &>/dev/null
   
   echo "Copying file back..."
   scp -r root@$SERVER_ADDRESS:~/"$file-hls" $1
   
   echo "Updating status.json..."
   # Update the status file
   
   echo "Found downloaded URL: '$DOWNLOADED_URL'"
   echo "Setting to complete..."
   flock $STATUS_FILE.lock \
   jq --arg url "$DOWNLOADED_URL" \
      --arg name "$file" \
      '.completed |= . + [{
         download_name: $name,
         url: $url
      }]' $STATUS_FILE | \
   sponge $STATUS_FILE
   
   echo "Removing old values..."
   flock $STATUS_FILE.lock \
   jq --arg name "$file" \
      'del(.downloaded[] | select(.download_name == $name))' \
      $STATUS_FILE | \
   sponge $STATUS_FILE
   
   echo "HLS transcode of $file complete"
done

# Delete original media
for file in "${@:2}"
do
   echo "Removing original file at $1/$file"
   rm "$1/$file"
done