#!/bin/sh
SERVICE_NAME=BedrockConnect
PATH_TO_JAR=/usr/local/bin/BedrockConnect.jar
PID_PATH_NAME=/tmp/BedRockService-pid
OPTS="nodb=true custom_servers=/etc/bedrock_connect_servers.json"
case $1 in
start)
       echo "Starting $SERVICE_NAME ..."
  if [ ! -f $PID_PATH_NAME ]; then
       nohup java -jar $PATH_TO_JAR $OPTS /tmp 2>> /dev/null >>/dev/null &
                   echo $! > $PID_PATH_NAME
       echo "$SERVICE_NAME started ..."
  else
       echo "$SERVICE_NAME is already running ..."
  fi
;;
stop)
  if [ -f $PID_PATH_NAME ]; then
         PID=$(cat $PID_PATH_NAME);
         echo "$SERVICE_NAME stopping ..."
         kill $PID;
         echo "$SERVICE_NAME stopped ..."
         rm $PID_PATH_NAME
  else
         echo "$SERVICE_NAME is not running ..."
  fi
;;
restart)
  if [ -f $PID_PATH_NAME ]; then
      PID=$(cat $PID_PATH_NAME);
      echo "$SERVICE_NAME stopping ...";
      kill $PID;
      echo "$SERVICE_NAME stopped ...";
      rm $PID_PATH_NAME
      echo "$SERVICE_NAME starting ..."
      nohup java -jar $PATH_TO_JAR $OPTS /tmp 2>> /dev/null >> /dev/null &
      echo $! > $PID_PATH_NAME
      echo "$SERVICE_NAME started ..."
  else
      echo "$SERVICE_NAME is not running ..."
     fi     ;;
 esac
