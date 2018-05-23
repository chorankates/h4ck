#!/bin/bash
## decompile.sh - find .class files and decompile them

DIR=$1
IB_JAR="./WiFiDeviceAPI.jar"
CFR_JAR="./cfr_0_129.jar"

if [ ! -f ${CFR_JAR} ]; then
  echo "could not find cfr JAR[${CFR_JAR}]"
  exit 1
fi

7z x ${IB_JAR}


for f in $(find ${DIR} -iname '*.class'); do
  NEW_F=`echo ${f} | sed -e "s/class/java/"`
  echo "${f} -> ${NEW_F}"
  java -jar ${CFR_JAR} ${f} > ${NEW_F}
done

