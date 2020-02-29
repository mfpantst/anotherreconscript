import json,urllib.request, csv, pandas, time, argparse

parser = argparse.ArgumentParser()

parser.add_argument('-i', dest='website')
parser.add_argument('-o', dest='output_directory')
parser.add_argument('-a', dest='api_key')
parser.add_argument('-d', dest='directory')

# Primary Variables
args = parser.parse_args()
directory = args.directory
api_key = args.api_key
output_directory = args.output_directory
website = args.website

with open(f'{directory}/{website}.txt', "r") as domains:
    open(f'{output_directory}{website}.csv',"w+") 
    for domain in domains:
        #Api Request String, write to dataframe and convert to CSV with output. Sleep 1 sec
        data = urllib.request.urlopen(f"https://api.builtwith.com/free1/api.json?KEY={api_key}&LOOKUP={domain}").read()
        df = pandas.read_json(data)
        domain = domain.rstrip()
        domain = domain.replace(" ","")
        print(domain)
        df.to_csv(f'{output_directory}/{website}.csv', mode='a')
        time.sleep(1.1)

