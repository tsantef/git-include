#!/bin/sh

include_path="~/.gitincludes"

dashless=$(basename "$0" | sed -e 's/-/ /')
USAGE="add [--reference <reference>] <repository> [<path>]
   or: $dashless update"

usage() 
{
  echo "$USAGE"
  exit 1
}

cmd_add()
{

  # parse $args after "include add".
  while test $# -ne 0
  do
    case "$1" in
    --reference)
      case "$2" in '') usage ;; esac
      reference="--reference=$2"
      shift
      ;;
    --reference=*)
      reference="$1"
      shift
      ;;
    --)
      shift
      break
      ;;
    -*)
      usage
      ;;
    *)
      break
      ;;
    esac
    shift
  done

  repo=$1
  name=$(echo "$repo" | sed -e 's|/$||' -e 's|:*/*\.git$||' -e 's|.*[/:]||g')
  path=$2

  if test -z "$path"; then
    path=$name
  fi

  if test -z "$repo" -o -z "$path"; then
    usage
  fi

  git config -f .gitincludes include."$name".path $path
  git config -f .gitincludes include."$name".url $repo
  git config -f .gitincludes include."$name".ref $reference

}

cmd_update() 
{
  # loop 
  git config -f .gitincludes --get-regexp '^include\..*\.path$' |
  while read line
  do
    # get repo properties
    name=$(echo "$line" | sed -n -e 's/^include\.\(.*\)\.path.*/\1/p')
    path=$(git config -f .gitincludes include."$name".path)
    url=$(git config -f .gitincludes include."$name".url)
    ref=$(git config -f .gitincludes include."$name".ref)
    refpath=$(echo "$ref" | sed -n -e 's/\//-/p')
    urlhash=$(echo "$url" | md5)
    local_repo="$name"_"$refpath"_"$urlhash"
    local_repo_path="$include_path"/"$local_repo"

    if [ ! -e "$local_repo_path" ]; then
      # clone repo
      git clone "$url" "$local_repo_path"
    else
      # update repo
      `cd "$local_repo_path" && git fetch`
    fi

    # reset repo to ref
    `cd "$local_repo_path" && git reset --hard "$ref"`

    # copy repo into super project
    cp -R "$local_repo_path" "$path"

    # remove .git from copied repo
    rm -rf "$path"/.git

  done
}

# Parse command line
while test $# != 0 && test -z "$command"
do
  case "$1" in
  add | update)
    command=$1
    ;;
  esac
  shift
done

# No command word defaults to "update"
if test -z "$command"; then
  usage
fi

"cmd_$command" "$@"
  