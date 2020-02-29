Another Recon Script

Use this to run basic recon, this script is intended specifically to test for XSS vulnerabilities and identify components of websites where vulnerabilities could exist.

Use the runRecon.sh script to run everthing- this requires having certain tools pre-installed:
  Sublist3r
  httprobe
  dirsearch
  Arjun
  Aquatone
  ffuf
  XSStrike

You can use config.sh to control the program and set file directories for individual components and where to store outputs.

When you first download you'll need to make executable runRecon.sh (chmod +x ./runRecon.sh)

If you find this useful, and want to modify- feel free, I think I set the code up in a fairly modulary way so you could add other domain enumerations, or testing as needed.

To-Do:
  Add in other basic recon tools, Nmap, Scraping data, etc to the mix
  Get a better feel for using the XSStrike toolkit
  Add in Amass to compliment the use of Sublist3r
  Improve dirsearch output to generate https results as well as http results
