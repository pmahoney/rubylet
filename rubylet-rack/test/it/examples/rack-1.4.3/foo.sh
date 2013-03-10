dir=foo
start=$(date "+%s")  


let elapsed=$(date "+%s")-$start
echo "<measurement><name>$dir</name><value>$elapsed</value></measurement>"

cat <<EOF >> timings.xml
  </system-out>
  <system-err>
  </system-err>
</testsuite>
EOF
