#!/usr/bin/env bash

usage ()
{
  echo -e "Usage: $0 [OPTIONS] COMMANDS\n"\
  'OPTIONS:\n'\
  '  -h       | --help       \n'\
  '  -l       | --list       list VERSIONS that can be set via environment variables\n'
}

buildargscommand() {
  local buildargs='' envvar
  for i in $(cat Dockerfile|grep '^ARG.*_VERSION'|sed 's/^ARG \(.*\)=.*$/\1/'|sort -u);do
    envvar=$(env|grep $i)
    if [[ -n $envvar ]]; then
      buildargs=${buildargs}"--build-arg ${i}=${envvar#*=} "
    fi
  done
  echo $buildargs
}

listversionscommand() {
  local version envvar
  for i in $(cat Dockerfile|grep '^ARG.*_VERSION'|sed 's/^ARG //'|sort -u);do
    version=${i#*=}
    name=${i%=*}
    envvar=$(env|grep $name)
    if [[ -n $envvar ]]; then
      echo "${name}=${envvar#*=}"
    else
      echo $i
    fi
  done
}

commands ()
{
  if [[ $# != 0 ]]; then
    usage
    exit 1
  fi
  buildargscommand
}

while :
do
  case "$1" in
    -h | --help)
	  usage
	  exit 0
	  ;;
    -l | --list)
	  listversionscommand
	  exit 0
	  ;;
    --)
      shift
      break
      ;;
    -*)
      echo "Error: Unknown option: $1" >&2
      exit 1
      ;;
    *)
      break
      ;;
  esac
done
commands $*
