#!/bin/sh

wcc_path=${1}

cd ${wcc_path}
/usr/bin/bundle install --path=vendor/bundle
/usr/bin/bundle update
