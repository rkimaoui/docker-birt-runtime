FROM tomcat:8.5

ARG BIRT_RT_DL_URL=http://download.eclipse.org/birt/downloads/drops/R-R1-4_5_0-201506092134/birt-runtime-4.5.0-20150609.zip
ARG BIRT_RT_FILE=birt-runtime-4.5.0-20150609.zip
ARG BIRT_RT_SHA512=375f8022ab082909a6ddbccc70e4e23648fa91e68ea599bee343a8439e3e1ea8591a442dacf6cd959a7bc771a1650238675983fa52236bbaa9fd1b8c29ffd62e
ARG MYSQL_JDBC_URL=http://cdn.mysql.com//Downloads/Connector-J/mysql-connector-java-5.1.40.tar.gz
ARG MYSQL_JDBC_FILE=mysql-connector-java-5.1.40.tar.gz
ARG MYSQL_JDBC_MD5=415a375cf8a096ef0aa775a4ae36916d
ARG POSTGRESQL_JDBC_URL=https://jdbc.postgresql.org/download/postgresql-9.4.1212.jar
ARG POSTGRESQL_JDBC_FILE=postgresql-9.4.1212.jar

ENV CLASSPATH=$CATALINA_HOME/bin/bootstrap.jar:$CATALINA_HOME/bin/tomcat-juli.jar \
  BIRT_VIEWER_HOME=$CATALINA_HOME/webapps/birt-viewer

WORKDIR /tmp
RUN echo 'Start downloading' \
  # Download birt-runtime
  && curl -o ${BIRT_RT_FILE} ${BIRT_RT_DL_URL} \
  && printf "%s  %s" ${BIRT_RT_SHA512} ${BIRT_RT_FILE} | sha512sum -c --status - \
  && mkdir -p /tmp/birt \
  && unzip ${BIRT_RT_FILE} -d /tmp/birt/ \
  && mv ./birt/birt-runtime-4_5_0/WebViewerExample ${BIRT_VIEWER_HOME} \
  && rm -r ./birt \
  && rm ./${BIRT_RT_FILE} \

  # Install JDBC
  # MySQL
  && curl -o ${MYSQL_JDBC_FILE} ${MYSQL_JDBC_URL} \
  && printf "%s  %s" ${MYSQL_JDBC_MD5} ${MYSQL_JDBC_FILE} | md5sum -c --status - \
  && echo "mysql-connector-java-5.1.40/mysql-connector-java-5.1.40-bin.jar" > mysql_jdbc.include \
  && tar -x -T ./mysql_jdbc.include -f ${MYSQL_JDBC_FILE} \
  && mv ./mysql-connector-java-5.1.40/mysql-connector-java-5.1.40-bin.jar ${BIRT_VIEWER_HOME}/WEB-INF/lib/ \
  && rm -r ./mysql-connector-java-5.1.40 \
  && rm ./mysql_jdbc.include \
  && rm ./${MYSQL_JDBC_FILE} \

  # PostgreSQL
  && curl -o ${POSTGRESQL_JDBC_FILE} ${POSTGRESQL_JDBC_URL} \
  && mv ./${POSTGRESQL_JDBC_FILE} ${BIRT_VIEWER_HOME}/WEB-INF/lib/

# Configure
ENV TOMCAT_USER=tomcat \
  TOMCAT_PASSWORD=12345678

RUN sed -i "s/<\/tomcat-users>/<role rolename=\"manager-gui\"\/>\n<user username=\"${TOMCAT_USER}\" password=\"${TOMCAT_PASSWORD}\" roles=\"manager-gui\"\/>\n<\/tomcat-users>/" $CATALINA_HOME/conf/tomcat-users.xml \
  # since tomcat 8.5 disallow access manager from anywhere but localhost
  && mkdir -p $CATALINA_HOME/conf/Catalina/localhost \
  && echo '<Context privileged="true" antiResourceLocking="false" docBase="${catalina.home}/webapps/manager"><Valve className="org.apache.catalina.valves.RemoteAddrValve" allow="^.*$" /></Context>' | tee $CATALINA_HOME/conf/Catalina/localhost/manager.xml \
  && sed -i ':a;N;$!ba;s/BIRT_VIEWER_WORKING_FOLDER<\/param-name>\n\t\t<param-value>/BIRT_VIEWER_WORKING_FOLDER<\/param-name>\n\t\t<param-value>\/opt\/reports/g' ${BIRT_VIEWER_HOME}/WEB-INF/web.xml

VOLUME /opt/reports

CMD ["catalina.sh", "run"]
