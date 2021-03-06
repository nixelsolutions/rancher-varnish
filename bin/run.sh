#!/bin/bash

set -e

[ "$DEBUG" == "1" ] && set -x && set +e

if [ "${BACKEND_PORT}" == "**ChangeMe**" -o -z "${BACKEND_PORT}" ]; then
   echo "*** ERROR: you need to define BACKEND_PORT environment variable - Exiting ..."
   exit 1
fi

if [ "${BACKEND_HEALTHCHECK}" == "**ChangeMe**" -o -z "${BACKEND_HEALTHCHECK}" ]; then
   echo "*** ERROR: you need to define BACKEND_HEALTHCHECK environment variable - Exiting ..."
   exit 1
fi

if [ "${MAX_CACHE_SIZE}" == "**ChangeMe**" -o -z "${MAX_CACHE_SIZE}" ]; then
   echo "*** ERROR: you need to define MAX_CACHE_SIZE environment variable - Exiting ..."
   exit 1
fi

if [ "${HTTP_PORT}" == "**ChangeMe**" -o -z "${HTTP_PORT}" ]; then
   echo "*** ERROR: you need to define HTTP_PORT environment variable - Exiting ..."
   exit 1
fi

sleep 5
BACKEND_SERVERS=`dig +short ${LINK_NAME} | sort`
export BACKEND_SERVERS=`echo ${BACKEND_SERVERS} | sed "s/ /,/g"`
if [ -z "${BACKEND_SERVERS}" ]; then
   echo "*** ERROR: Could not determine which backends are linked to this varnish service."
   echo "*** Is the link named \"${LINK_NAME}\"? If not, please relink the service"
   echo "*** Exiting ..."
   exit 1
fi

echo "=> Configuring Varnish..."
cp ${VARNISH_CFG_DIR}/start.vcl ${VARNISH_CFG_DIR}/default.vcl
backends=0
default_director="sub vcl_init {\n  new bar = directors.round_robin();"
for backend in `echo ${BACKEND_SERVERS} | sed "s/,/ /g"`; do
   echo "=> Adding backend $backend to Varnish configuration..."
   backend_id=$((backends++))
   echo "\
backend web${backend_id} { \
  .host = \"${backend}\"; \
  .port = \"${BACKEND_PORT}\"; \
  .probe = { .url = \"${BACKEND_HEALTHCHECK}\"; .timeout = 5s; .interval = 5s; .window = 5; .threshold = 3; } \
}" >> ${VARNISH_CFG_DIR}/default.vcl
   default_director="${default_director}\n    bar.add_backend(web${backend_id});"
done
default_director="${default_director}\n}"
echo -e "\n${default_director}" >> ${VARNISH_CFG_DIR}/default.vcl
cat ${VARNISH_CFG_DIR}/end.vcl >> ${VARNISH_CFG_DIR}/default.vcl

echo "=> Starting Varnish with these parameters:"
echo "MAX_CACHE_SIZE = ${MAX_CACHE_SIZE}"
echo "HTTP_PORT = ${HTTP_PORT}"
echo "BACKEND_SERVERS = ${BACKEND_SERVERS}"

/usr/bin/supervisord
