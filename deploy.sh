#!/bin/bash

set -e

GITHUB_TOKEN="${1}"
GITHUB_REPO="krossovochkin/krossovochkin.github.io"
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

if [[ -z "${GITHUB_TOKEN}" ]]; then
  echo "token missing"
fi

if [[ -z "${GITHUB_REPO}" ]]; then
  echo "repo missing"
fi

if [[ -z "${GITHUB_TOKEN}" || -z "${GITHUB_REPO}" ]]; then
  echo "local"
  git push origin "${GITHUB_BRANCH}"
else
  echo "ci"
  git remote set-url origin "https://${GITHUB_TOKEN}:x-oauth-basic@github.com/${GITHUB_REPO}.git"
  git push --quiet origin "${GITHUB_BRANCH}"
fi
