#!/bin/bash

run() {
  pushd $1
  shift
  echo "=== " "$@"
  "$@" || exit 1
  popd
}

run rubylet bundle install
run rubylet jruby -G -S rake test:spec test:integration

run rubylet-tasks bundle install
run rubylet-tasks jruby -G -S rake test

run rubylet-ee mvn verify
