#!/bin/bash
kubectl port-forward -n team-mikroways-demo-default \
  svc/team-mikroways-demo-default-in-app-serve-static 8081:80 &
pid1=$!
echo ${pid1}

kubectl port-forward -n team-mikroways-demo-testing \
  svc/team-mikroways-demo-testing-in-app-serve-static 8082:80 &
pid2=$!
echo ${pid2}

kubectl port-forward -n team-mikroways-demo-prod \
  svc/team-mikroways-demo-prod-in-app-serve-static 8083:80 &
pid3=$!
echo ${pid3}

kubectl port-forward -n team-mikroways-redmine-testing \
  svc/team-mikroways-redmine-testing-in-app 8084:80 &
pid4=$!
echo ${pid4}

kubectl port-forward -n team-mikroways-wp-example-prod \
  svc/team-mikroways-wp-example-prod-in-app-wordpress 8085:80 &
pid5=$!
echo ${pid5}

trap 'kill -15 ${pid1} ${pid2} ${pid3}; echo "killed: $pid1 $pid2 $pid3"' INT
wait
