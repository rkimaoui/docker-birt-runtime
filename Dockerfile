FROM tomcat:8.5-alpine

ARG BIRT_RT_DL_URL=http://download.eclipse.org/birt/downloads/drops/R-R1-4.6.0-201606072112/birt-runtime-4.6.0-20160607.zip
ARG BIRT_RT_FILE=birt-runtime-4.6.0-20160607.zip
ARG BIRT_RT_SHA512=945577b2327703ed4cd8e0c8a65adaf35aba41ba34a43193f73494b1aa01c57950367f6fec5c6b6dd93f9de9e052e7a289958603e35880f63de75aeccab09362
ARG MYSQL_JDBC_URL=http://cdn.mysql.com//Downloads/Connector-J/mysql-connector-java-5.1.40.tar.gz
ARG MYSQL_JDBC_FILE=mysql-connector-java-5.1.40.tar.gz
ARG MYSQL_JDBC_MD5=415a375cf8a096ef0aa775a4ae36916d

ENV BIRT_VIEWER_HOME=$CATALINA_HOME/webapps/birt-viewer

RUN apk --no-cache add curl \
  && cd /tmp \

  # Download birt-runtime
  && curl -o ${BIRT_RT_FILE} ${BIRT_RT_DL_URL} \
  && printf "%s  %s" ${BIRT_RT_SHA512} ${BIRT_RT_FILE} | sha512sum -c -s - \
  && mkdir -p /tmp/birt \
  && unzip ${BIRT_RT_FILE} -d /tmp/birt/ \
  && mv ./birt/WebViewerExample ${BIRT_VIEWER_HOME} \
  && rm -r ./birt \
  && rm ./${BIRT_RT_FILE} \

  # Install JDBC
  # MySQL
  && curl -o ${MYSQL_JDBC_FILE} ${MYSQL_JDBC_URL} \
  && printf "%s  %s" ${MYSQL_JDBC_MD5} ${MYSQL_JDBC_FILE} | md5sum -c -s - \
  && echo "mysql-connector-java-5.1.40/mysql-connector-java-5.1.40-bin.jar" > mysql_jdbc.include \
  && tar -x -T ./mysql_jdbc.include -f ${MYSQL_JDBC_FILE} \
  && mv ./mysql-connector-java-5.1.40/mysql-connector-java-5.1.40-bin.jar ${BIRT_VIEWER_HOME}/WEB-INF/lib/ \
  && rm -r ./mysql-connector-java-5.1.40 \
  && rm ./mysql_jdbc.include \
  && rm ./${MYSQL_JDBC_FILE}

# Configure
ENV TOMCAT_USER=tomcat \
  TOMCAT_PASSWORD=12345678

RUN sed -i "s/<\/tomcat-users>/<role rolename=\"manager-gui\"\/>\n<user username=\"${TOMCAT_USER}\" password=\"${TOMCAT_PASSWORD}\" roles=\"manager-gui\"\/>\n<\/tomcat-users>/" $CATALINA_HOME/conf/tomcat-users.xml \
  # since tomcat 8.5 disallow access manager from anywhere but localhost
  && mkdir -p $CATALINA_HOME/conf/Catalina/localhost \
  && echo '<Context privileged="true" antiResourceLocking="false" docBase="${catalina.home}/webapps/manager"><Valve className="org.apache.catalina.valves.RemoteAddrValve" allow="^.*$" /></Context>' | tee $CATALINA_HOME/conf/Catalina/localhost/manager.xml

# This is a fix only for 4.6.0
RUN apk --no-cache add zip \
  && cd ${BIRT_VIEWER_HOME}/WEB-INF/lib \
  && zip -d ./org.eclipse.birt.runtime_4.6.0-20160607.jar META-INF/ECLIPSE_.RSA \
  && zip -d org.eclipse.birt.runtime_4.6.0-20160607.jar META-INF/ECLIPSE_.SF

CMD ["catalina.sh", "run"]
