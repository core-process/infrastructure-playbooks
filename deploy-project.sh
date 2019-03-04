#!/bin/bash
set -e

OLD_DIR="`pwd`"
PLAYBOOK_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DOCKER_PULL="false"

while getopts fp:m:b:v: option
do
  case "${option}" in
    f)
      DOCKER_PULL="true"
      ;;
    p)
      PLAYBOOK_DIR="$OPTARG"
      ;;
    s)
      PROJECT_SOURCE="$OPTARG"
      ;;
    m)
      PROJECT_MODE="$OPTARG"
      ;;
    b)
      PROJECT_BRANCH="$OPTARG"
      ;;
    v)
      PROJECT_VERSION="$OPTARG"
      ;;
    \?)
      echo "Usage: $0 [-f] [-p playbook_dir] [-s project_source] [-m project_mode] [-p project_branch] [-v project_version]"
      echo "           -f = force pull from registry"
      exit 1
      ;;
  esac
done

: ${PROJECT_SOURCE:="`pwd`"}
: ${PROJECT_BRANCH:="`cd "$PROJECT_SOURCE"; git rev-parse --abbrev-ref HEAD 2> /dev/null || echo 'unknown'`"}
: ${PROJECT_VERSION:="`cd "$PROJECT_SOURCE"; git rev-parse --verify HEAD 2> /dev/null || echo 'unknown'`"}
: ${PROJECT_MODE:="`if [ "$PROJECT_BRANCH" == "production" ]; then echo "production"; else echo "staging"; fi`"}

echo "Deploy:"
echo "* PLAYBOOK_DIR=$PLAYBOOK_DIR"
echo "* PROJECT_SOURCE=$PROJECT_SOURCE"
echo "* PROJECT_MODE=$PROJECT_MODE"
echo "* PROJECT_BRANCH=$PROJECT_BRANCH"
echo "* PROJECT_VERSION=$PROJECT_VERSION"

cd "$PLAYBOOK_DIR"
ansible-playbook $PLAYBOOK_DIR/deploy-project.yml -vvv -e docker_pull=$DOCKER_PULL -e project_mode=$PROJECT_MODE -e project_branch=$PROJECT_BRANCH -e project_version=$PROJECT_VERSION -e @$PROJECT_SOURCE/project.yml

cd "$OLD_DIR"
echo "Done!"
