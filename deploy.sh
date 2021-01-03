#!/bin/bash

set -e

printf "\033[0;32mClean up public folder...\033[0m\n"
cd public
git pull origin master
shopt -s extglob
rm -rf -- !(CNAME|.git|.|..)
cd ..

printf "\033[0;32mBuilding website...\033[0m\n"
hugo

printf "\033[0;32mDeploying updates to GitHub...\033[0m\n"
cd public
git add .
msg="rebuilding site $(date)"
if [ -n "$*" ]; then
	msg="$*"
fi
git commit -m "$msg"
git push origin master
