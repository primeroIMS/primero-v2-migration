#! /bin/bash

cd "$(dirname "$0")" || exit

# for model in "${recordsToImport[@]}"; do
for model in record-data-files/*; do
  (
    echo "==================================="
    echo "Loading $model"
    echo "==================================="
    cd "$(dirname "$0")/$model"
    for file in ./*.rb; do
      echo "-----------------------------------------------"
      echo "Loading file $(pwd)/${file:2}"
      echo "-----------------------------------------------"
      rails r "$(pwd)/${file:2}"
    done
  )
done
