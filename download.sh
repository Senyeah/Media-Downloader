#!/bin/bash

# Initialise session
SESSION_ID=$(uuidgen)
SESSION_READABLE_TIME="$(date +%c)"

DOWNLOAD_DIR=~/downloads/$SESSION_ID
mkdir -p $DOWNLOAD_DIR
cd $DOWNLOAD_DIR

# Create session ID–time map file (if it doesn't exist)
if ! [ -e ../sessions.json ]
then
   echo '{"sessions": {}}' > ../sessions.json
fi

# Update session files
echo '{"completed": [], "downloaded": [], "incomplete": [], "failed": []}' \
   > status.json

jq --arg id $SESSION_ID \
   --arg readable_time "$SESSION_READABLE_TIME" \
   '.sessions |= . + {($readable_time): $id}' ../sessions.json | \
sponge ../sessions.json

download_url() {
   youtube-dl $1 --output $2 &>/dev/null
   
   flock status.json.lock \
   jq --arg url $1 \
      --arg name $2 \
      --arg success $? \
      'if $success == "0" then
         .downloaded else .failed
       end |= . + [{
         download_name: $name,
         url: $url
       }] |
       del(.incomplete[] | select(.download_name == $name))' \
      status.json | \
   sponge status.json
}

for url in $1
do
   DOWNLOAD_NAME=$(uuidgen | shasum | awk '{print $1}').mp4   
   jq --arg name "$DOWNLOAD_NAME" \
      --arg url $url \
      '.incomplete |= . + [{
         download_name: $name,
         url: $url
      }]' \
      status.json | \
   sponge status.json
done

for url in $1
do
   DOWNLOAD_NAME=$(
      jq -r --arg url $url \
      '.incomplete[] | select(.url == $url) | .download_name' status.json
   )
   download_url $url $DOWNLOAD_NAME &
done

# Now we can transcode each of them to HLS
wait ; ~/transcode.sh $DOWNLOAD_DIR *.mp4