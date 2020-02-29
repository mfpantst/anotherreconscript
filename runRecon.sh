#!/bin/bash

#Load Variables and do file directory cleanup
source config.sh
rm -r "$output"/
#Make output Directories
mkdir "$output"
mkdir "$output"/combined
while IFS= read -r line; do 
  touch "$output"/combined/"$line".txt
done < "$input"

#Sublis3r domain enumeration
if test "$sublist3r" = "ON"; then
  mkdir "$output"/sublist3r 
  while IFS= read -r  line
  do
    python3 "$sublist3rpath"/sublist3r.py -d "$line" -o "$output"/sublist3r/"$line".txt
  done < "$input" 
fi

#Check results for website exists
if test "$httprobe" = "ON"; then
  mkdir "$output"/httprobe 
  while IFS= read -r  line
  do
    echo "$line" httprobe
    cd ~/go/bin/
    cat "$output"/sublist3r/"$line".txt | ./httprobe >"$output"/httprobe/"$line".txt
    cd "$output"
    cd ..
    cat "$output"/httprobe/"$line".txt > "$output"/combined/"$line".txt
    sort -u "$output"/combined/"$line".txt > "$output"/combined/"$line"srt.txt
    cp "$output"/combined/"$line"srt.txt "$output"/combined/"$line".tx
    rm "$output"/combined/"$line"srt.txt
done < "$input"
fi

#Search for directories and endpoints in alive domains
if test "$dirsearch" = "ON"; then
  mkdir "$output"/dirsearch 
  while IFS= read -r  line
  do
    touch "$output"/dirsearch/"$line".txt
    python3 "$dirsearchpath"/dirsearch.py -b --url-list="$output"/combined/"$line".txt -x 301,403,400,421 -e html,json,php --simple-report="$output"/dirsearch/"$line".txt
    cat "$output"/dirsearch/"$line".txt >> "$output"/combined/"$line".txt
    sort -u "$output"/combined/"$line".txt > "$output"/combined/"$line"srt.txt
    cp "$output"/combined/"$line"srt.txt "$output"/combined/"$line".txt
    rm "$output"/combined/"$line"srt.txt
  done < "$input"
fi

#Screenshot all found adresses
if test "$aquatone" = "ON"; then
  mkdir "$output"/aquatone
  while IFS= read -r line
  do
   mkdir "$output"/aquatone/"$line"
   cat "$output"/combined/"$line".txt | aquatone -out "$output"/aquatone/"$line"
  done < "$input"
fi

#Check all endpoints for hidden parameters
#Not sure why- but Arjun requires running within the directory
if test "$arjun" = "ON"; then
  mkdir "$output"/arjun 
  while IFS= read -r line
    do
    cd ~/Arjun
    python3 arjun.py --urls "$output"/combined/"$line".txt --get -t 8 -o "$output"/arjun/"$line".json
    cd "$output"
    cd ..
  done < "$input"
fi

#Code for running XSS testing against targets
if test "$runxss" = "ON"; then
  mkdir "$output"/runxss
  mkdir "$output"/runxxs/paramslist 

  #Find all JSON outputs and make a flat list of urls + parameters
  while IFS= read -r line
  do 
    touch "$output"/runxss/paramslist/"$line".txt
    python3 makeparams.py -f "$output"/arjun/"$line".json >> "$output"/runxss/paramslist/"$line".txt
  done < "$input"

  # Simple FFUF run using a payloads input file- for xss testing
  mkdir "$output"/runxss/ffuf
  mkdir "$output"/runxss/aquatone
  while IFS= read -r line
  do
    touch "$output"/runxss/ffuf/"$line".txt  
    #Simple Fuzz and Aquatone Pass
    while read params; do
      cd ~/go/bin/
      echo "$params" >> "$output"/runxss/ffuf/"$line".txt
      ./ffuf -w "$payloadspath" -u "$params"FUZZ -r -v  >> "$output"/runxss/ffuf/"$line".txt
      cd "$output"
      cd ..
      
      #Separate Aquatone Pass on XSS payload fuzz
      while read fuzz; do
        cat "$params""$fuzz" | aquatone -out "$output"/runxss/aquatone
      done < "$payloadspath"
    done < "$output"/runxss/paramslist/"$line".txt
  done < "$input"

  #XSStrike pass
  mkdir "$output"/runxss/xsstrike
  while IFS= read -r  line
  do
    touch "$output"/runxss/xsstrike/"$line".log
    python3 "$xsstrikepath"/xsstrike.py -u "$output"/combined/"$line" -t 7 --file-log-level INFO --log-file "$output"/runxss/xsstrike/"$line".log
  done < "$input"
fi 

exit 0
