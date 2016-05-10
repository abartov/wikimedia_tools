#!/bin/bash
source "$HOME/.rvm/scripts/rvm"
rvm use 2.1
cd /data/project/pileviews/wikimedia_tools/pileviews
export PILEVIEWS_PORT=$1
exec rackup pileviews.ru
