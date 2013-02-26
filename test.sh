#!/bin/bash

run() {
  pushd $1
  shift
  echo "=== " "$@"
  "$@" || exit 1
  popd
}

run rubylet bundle install
run rubylet jruby -G -S rake test:spec
# run these one by one to avoid oom on travis
pushd rubylet
for test in test/it/*_it.rb; do
    echo "=== $test" 
    jruby -G -S rake test:integration TEST="$test" || exit 1
done
popd

run rubylet-tasks bundle install
run rubylet-tasks jruby -G -S rake test

run rubylet-ee mvn verify
