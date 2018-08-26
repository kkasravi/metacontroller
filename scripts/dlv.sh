#!/usr/bin/env bash

cleanup()
{
  if [[ -n $dlvcmd ]]; then
    echo killing $dlvcmd
    pkill -9 -f $dlvcmd
  fi
}
trap cleanup EXIT

waitforever()
{
  which gsleep >/dev/null
  if [[ $? == 1 ]]; then
    while true; do
      sleep 1
    done
  else
    gsleep infinity
  fi
}

cmd="dlv --listen=:2345 --headless=true --api-version=2 exec /go/bin/metacontroller -- --logtostderr -v=4 --discovery-interval=20s 2>&1>/dev/null &"
dlvcmd="${cmd% 2>&1>/dev/null &}"
eval $cmd
waitforever
