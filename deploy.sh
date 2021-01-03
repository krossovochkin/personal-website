#!/bin/bash

set -e

GITHUB_REPO="krossovochkin.github.io"
GITHUB_BRANCH="develop"

printf "\033[0;32mClean up public folder...\033[0m\n"
cd public
git checkout ${GITHUB_BRANCH} || git checkout -b ${GITHUB_BRANCH}
git pull origin ${GITHUB_BRANCH}
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

if [[ -z "${GITHUB_TOKEN}" || -z "${GITHUB_REPO}" ]]; then
  git push origin "${GITHUB_BRANCH}"
else
  git push --quiet "https://${GITHUB_TOKEN}:x-oauth-basic@github.com/${GITHUB_REPO}.git" "${GITHUB_BRANCH}"
fi
