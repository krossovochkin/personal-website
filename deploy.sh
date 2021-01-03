#!/bin/bash

set -e

GITHUB_TOKEN="${1}"
GITHUB_REPO="krossovochkin/krossovochkin.github.io"
GITHUB_BRANCH="master"
GITHUB_USERNAME="GitHub Actions CI"
GITHUB_EMAIL="ci@github"

printf "\033[0;32mClean up public folder...\033[0m\n"
cd public
git checkout ${GITHUB_BRANCH}
git pull origin ${GITHUB_BRANCH}
shopt -s extglob
rm -rf -- !(CNAME|.git|.|..)
cd ..

printf "\033[0;32mBuilding website...\033[0m\n"
hugo

printf "\033[0;32mDeploying updates to GitHub...\033[0m\n"
cd public

MESSAGE="rebuilding site $(date)"
git add .

if [[ -z "${GITHUB_TOKEN}" || -z "${GITHUB_REPO}" ]]; then
  git commit -m "$MESSAGE"
  git push origin "${GITHUB_BRANCH}"
else
  git config --global user.email GITHUB_EMAIL
  git config --global user.name GITHUB_USERNAME
  
  git commit -m "$MESSAGE"
  
  git push --quiet "https://${GITHUB_TOKEN}:x-oauth-basic@github.com/${GITHUB_REPO}.git" "${GITHUB_BRANCH}"
fi
