import json, argparse

parser = argparse.ArgumentParser()

parser.add_argument('-f', dest='filepath')
args = parser.parse_args()
filepath = args.filepath

with open(filepath) as json_file:
    data = json.load(json_file)
    #print(data)
    for item in data:
        #print(item)
        for params in data[item]:
            print(f"{item}?{params}=")

