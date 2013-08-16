#!/bin/bash

run() {
  pushd $1
  shift
  echo "=== " "$@"
  "$@" || exit 1
  popd
}

run rubylet-rack bundle install
run rubylet-rack jruby -G -S rake test:spec
run rubylet-rack jruby -G -S rake test:integration

run rubylet-tasks bundle install
run rubylet-tasks jruby -G -S rake test

run rubylet-ee mvn verify
