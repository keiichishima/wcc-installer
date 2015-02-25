#!/bin/sh

wcc_path=$1

cd ${wcc_path}
export RAILS_ENV=production
/usr/bin/bundle exec rake db:migrate
/usr/bin/bundle exec rake db:seed
/usr/bin/bundle exec rake assets:precompile
