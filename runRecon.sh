#!/bin/bash

#Load Variables and do file directory cleanup
source config.sh
if test "$resetresults" = "ON"; then
  rm -r "$output"
fi 

#Make output Directories
if [ ! -d "$output" ]; then
  mkdir "$output"
fi 
if [ ! -d "$output"/combined ]; then 
  mkdir "$output"/combined
fi

#Pre-Set up combined files for storing aggregated domain and directory results
while IFS= read -r line; do
  touch "$output"/combined/"$line".txt
  echo "$line" >> "$line".txt 
done < "$input"

#Sublis3r domain enumeration
if test "$sublist3r" = "ON"; then
  #check if output directory exists- create if not
  if [ ! -d "$output"/sublist3r ]
  then
    mkdir "$output"/sublist3r 
  fi
  while IFS= read -r line
  do
    python3 "$sublist3rpath"/sublist3r.py -d "$line" -o "$output"/sublist3r/"$line".txt
  done < "$input" 
fi

#Check results for website exists
if test "$httprobe" = "ON"; then
  #check if output directory exists- create if not
  if [ ! -d "$output"/httprobe ]; then 
    mkdir "$output"/httprobe 
  fi
  # Run httprobe against sublist3r, then concatenate results into combined outpout
  while IFS= read -r  line
  do
    echo "$line" httprobe
    cd ~/go/bin/
    cat "$output"/sublist3r/"$line".txt | ./httprobe >"$output"/httprobe/"$line".txt
    cd "$output"
    cd ..
    cat "$output"/httprobe/"$line".txt > "$output"/combined/"$line".txt
    
    #de-duplicate list of urls
    sort -u "$output"/combined/"$line".txt > "$output"/combined/"$line"srt.txt
    cp "$output"/combined/"$line"srt.txt "$output"/combined/"$line".txt
    rm "$output"/combined/"$line"srt.txt
done < "$input"
fi

#Nmap scans against input domains
if test "$runnmap" = "ON"; then
  #check if output directory exists- create if not
  if [ ! -d "$output"/nmap ]; then 
    mkdir "$output"/nmap 
  fi
  nmap -oA "$output"/nmap/"$line" -iL "$input"
fi

#Builtwith Scraping against sublist3r domains
if test "$runbuiltwith" = "ON"; then
  #check if output directory exists- create if not
  if [ ! -d "$output"/builtwith ]; then 
    mkdir "$output"/builtwith 
  fi
  while IFS= read -r  line
  do
    python3 runbwscrape.py -d "$output"/combined -i "$line" -o "$output"/builtwith/ -a "$builtwithapi"
  done < "$input"
fi

#Search for directories and endpoints in alive domains
if test "$dirsearch" = "ON"; then
  #check if output directory exists- create if not
  if [ ! -d "$output"/dirsearch ]; then 
    mkdir "$output"/dirsearch 
  fi
  while IFS= read -r  line
  do
    # initialize master file 
    touch "$output"/dirsearch/"$line".txt  
    echo "$line"
    while IFS= read -r individualurl
    do
    #Nested loop for testing each line of the combined results so far goes here
      python3 "$dirsearchpath"/dirsearch.py -b -u "$individualurl" -x 301,302,403,400,421,500 -e html,json,php --simple-report="$output"/dirsearch/tmp.txt
      cat "$output"/dirsearch/tmp.txt >> "$output"/dirsearch/"$line".txt
      rm "$output"/dirsearch/tmp.txt
    done <"$output"/combined/"$line".txt
    
    #Aggregate results and de-duplicate
    cat "$output"/dirsearch/"$line".txt >> "$output"/combined/"$line".txt
    #de-duplicate list of urls
    sort -u "$output"/combined/"$line".txt > "$output"/combined/"$line"srt.txt
    cp "$output"/combined/"$line"srt.txt "$output"/combined/"$line".txt
    rm "$output"/combined/"$line"srt.txt
  done < "$input"
fi

#Screenshot all found adresses
if test "$aquatone" = "ON"; then
  #check if output directory exists- create if not
  if [ ! -d "$output"/aquatone ]; then 
    mkdir "$output"/aquatone 
  fi
  while IFS= read -r line
  do
   mkdir "$output"/aquatone/"$line"
   cat "$output"/combined/"$line".txt | aquatone -out "$output"/aquatone/"$line"
  done < "$input"
fi

#Check all endpoints for hidden parameters
#Not sure why- but Arjun requires running within the directory
if test "$arjun" = "ON"; then
  #check if output directory exists- create if not
  if [ ! -d "$output"/arjun ]; then 
    mkdir "$output"/arjun 
  fi
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
  #check if output directory exists- create if not
  if [ ! -d "$output"/runxss ]; then 
    mkdir "$output"/runxss 
  fi
  #check if output directory exists- create if not
  if [ ! -d "$output"/runxss/paramslist ]; then 
    mkdir "$output"/runxss/paramslist 
  fi

  #Find all JSON outputs and make a flat list of urls + parameters
  while IFS= read -r line
  do 
    touch "$output"/runxss/paramslist/"$line".txt
    python3 makeparams.py -f "$output"/arjun/"$line".json >> "$output"/runxss/paramslist/"$line".txt
  done < "$input"

  #check if output directory exists- create if not
  if [ ! -d "$output"/runxss/ffuf ]; then 
    mkdir "$output"/runxss/ffuf 
  fi
  if [ ! -d "$output"/runxss/aquatone ]; then 
    mkdir "$output"/runxss/aquatone 
  fi

  # Simple FFUF run using a payloads input file- for xss testing
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
  #check if output directory exists- create if not
  if [ ! -d "$output"/runxss/xsstrike ]; then 
    mkdir "$output"/runxss/xsstrike 
  fi

  #Run XSStrike three ways:
  # simply test all endpoints (1)
  # crawl subdomains (2)
  # check for blind xss (3)
  while IFS= read -r  line
  do
    touch "$output"/runxss/xsstrike/"$line".log
    python3 "$xsstrikepath"/xsstrike.py --seeds "$output"/combined/"$line".txt -t 7 --file-log-level INFO --log-file "$output"/runxss/xsstrike/"$line".log
     touch "$output"/runxss/xsstrike/"$line"params.log
    python3 "$xsstrikepath"/xsstrike.py --seeds "$output"/combined/"$line".txt -t 7 --params --file-log-level INFO --log-file "$output"/runxss/xsstrike/"$line"params.log
    touch "$output"/runxss/xsstrike/"$line"crawl.log
    python3 "$xsstrikepath"/xsstrike.py -u "$line" --crawl -l 3 -t 7 --file-log-level INFO --log-file "$output"/runxss/xsstrike/"$line"crawl.log
    touch "$output"/runxss/xsstrike/"$line"blind.log
    python3 "$xsstrikepath"/xsstrike.py --seeds "$output"/combined/"$line".txt --blind -t 7 --file-log-level INFO --log-file "$output"/runxss/xsstrike/"$line"blind.log
  done < "$input"
fi 

exit 0