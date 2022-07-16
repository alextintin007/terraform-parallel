#!/bin/bash

zones=(
   "europe-north1-a"   "europe-north1-b"   "europe-north1-c"
    "europe-west1-b"    "europe-west1-c"    "europe-west1-d"
    "europe-west2-a"    "europe-west2-b"    "europe-west2-c"
    "europe-west3-a"    "europe-west3-b"    "europe-west3-c"
    "europe-west4-a"    "europe-west4-b"    "europe-west4-c"
    "europe-west6-a"    "europe-west6-b"    "europe-west6-c"
    )

# for test #
names=("1" "2" "3" "4" "5")
#"6" "7" "8" "9" "10" "11" "12" "13" "14" "15" "16" "17" "18" "19" "20" "21" "22" "23" "24" "25" "26" "27" "28" "29" "30" "31" "32" "33" "34" "35" "36" "37" "38" "39" "40" "41" "42" "43" "44" "45" "46" "47" "48" "49" "50" "51" "52" "53" "54" "55" "56" "57" "58" "59" "60")
emails=("1" "2" "3" "4" "5")
#"6" "7" "8" "9" "10" "11" "12" "13" "14" "15" "16" "17" "18" "19" "20" "21" "22" "23" "24" "25" "26" "27" "28" "29" "30" "31" "32" "33" "34" "35" "36" "37" "38" "39" "40" "41" "42" "43" "44" "45" "46" "47" "48" "49" "50" "51" "52" "53" "54" "55" "56" "57" "58" "59" "60")

len=${#names[@]}

mkdir -p logs
mkdir -p s


echo "Updating terraform providers..."
sleep 1
cd terraform
terraform init 
cd ..


for (( i=0; i<${len}; i++))     
do
    (( (( $i + 1 ) %  50) == 0 )) && sleep 100 # GCEapi limit 50 per user per 100 seconds
    mkdir -p s/${names[$i]}
    cd s/${names[$i]}
    ln -s ../../terraform/* .
    ln -s ../../terraform/.t* .
    terraform init &&
    terraform apply -auto-approve -var email=${emails[$i]} -var name=${names[$i]}  -var zone=${zones[$(($i % ${#zones[@]}))]}  &> ../../logs/${names[$i]}.log &
    cd ../.. 
    clear
    echo $i
    sleep 7
done
