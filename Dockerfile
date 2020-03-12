FROM debian
#FROM localhost:5000/ss_py:2019_10_11

# chess-baseimage:latest
# ccadapter:latest

ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /home/navex
ENV HOME=/home/navex
ENV TZ=America/New_York

#some needed packages
RUN apt-get update -y && \
   apt-get install -y --no-install-recommends apt-utils && \
#   apt-get install -y --fix-missing python && \
#   apt-get install -y --fix-missing python-pip && \
#   apt-get install -y --fix-missing python3 && \
#   apt-get install -y --fix-missing python3-pip && \
   apt-get install -y --fix-missing wget && \
   apt-get install -y --fix-missing gnupg && \
   apt-get install -y --fix-missing git && \
   apt-get install -y --fix-missing php-pear && \
 #  apt-get install -y --fix-missing  php7.2-dev && \
    apt-get install -y --fix-missing  php-dev && \
   apt-get install -y --fix-missing maven && \
   apt-get install -y --fix-missing gradle && \
#   apt-get -y --fix-missing install openjdk-8-jdk && \
   apt-get update -y && apt-get install -y --fix-missing php && \
   apt-get -y --fix-missing install graphviz-dev

RUN wget -qO - https://adoptopenjdk.jfrog.io/adoptopenjdk/api/gpg/key/public | apt-key add -
RUN apt-get install -y software-properties-common
RUN add-apt-repository --yes https://adoptopenjdk.jfrog.io/adoptopenjdk/deb/ && \
    apt-get update
RUN apt-get install adoptopenjdk-8-hotspot

#change default java to version 8 because of batch-import
#RUN update-alternatives --install /usr/bin/java java  /usr/lib/jvm/java-8-openjdk-amd64/jre/bin/java 1119
#RUN update-alternatives --install /usr/bin/javac javac  /usr/lib/jvm/java-8-openjdk-amd64/bin/javac 1119
RUN update-alternatives --install /usr/bin/java java  /usr/lib/jvm/adoptopenjdk-8-hotspot-amd64/jre/bin/java 1119
RUN update-alternatives --install /usr/bin/javac javac  /usr/lib/jvm/adoptopenjdk-8-hotspot-amd64/bin/javac 1119


#RUN update-alternatives --install /usr/bin/python python /usr/bin/python3.6 30


RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

#install neo4j 2.1.5
RUN wget -O - https://debian.neo4j.org/neotechnology.gpg.key | apt-key add -
RUN echo 'deb https://debian.neo4j.org/repo stable/' | tee /etc/apt/sources.list.d/neo4j.list 
RUN apt-get update 
RUN apt-get install -y python3-distutils
RUN apt-get install -y --fix-missing neo4j=2.1.5
RUN apt-get install -y python3-setuptools
RUN apt-get install -y python3-pygraphviz


#install ast for PHP. ast.so exposes PHP's AST and creates nodes and edges of the AST
RUN mkdir dependencies && cd dependencies 
RUN pecl install ast-0.1.7 && sed -i '929i extension=ast.so' /etc/php/7.3/cli/php.ini

#get joern-uic
RUN cd dependencies && git clone https://github.com/rigelgjomemo/joern-uic.git
#TODO: path is hardcoded in the gradle file but only absolute path works. Figure out relative paths on build.gradle

RUN sed -i "s|/home/user/navex/joern|$HOME/dependencies/joern-uic|" dependencies/joern-uic/projects/extensions/joern-php/build.gradle && \
    cd dependencies/joern-uic && \
   gradle deploy -x test -Dorg.gradle.java.home=/usr/lib/jvm/adoptopenjdk-8-hotspot-amd64/

#get php-joern
RUN cd dependencies && git clone https://github.com/malteskoruppa/phpjoern.git

RUN mkdir temp


#batch-import imports nodes and edges into Neo4J
RUN cd dependencies && \
    git clone https://github.com/jexp/batch-import.git -b 2.1 && \
    cd batch-import && \
    mvn clean compile assembly:single 

#get Z3
RUN cd dependencies && git clone https://github.com/Z3Prover/z3.git && cd z3 && \
   python3 scripts/mk_make.py && cd build && make 

#get JAlin plugin for neo4j
RUN wget http://mlsec.org/joern/lib/neo4j-gremlin-plugin-2.1-SNAPSHOT-server-plugin.zip
RUN unzip neo4j-gremlin-plugin-2.1-SNAPSHOT-server-plugin.zip -d /var/lib/neo4j/plugins/gremlin-plugin

#get py2neo and pika


RUN apt install -y python3-pip
RUN pip3 install py2neo==2.0
RUN pip3 install pika==1.0.1


COPY exampleApps/MyApp2/ ./MyApp2
RUN git clone https://github.com/satwikkansal/schoolmate.git ./schoolmate
COPY exampleApps/oscommerce/ ./oscommerce
RUN cp -r MyApp2 /var/www/html && cp -r schoolmate /var/www/html && cp -r oscommerce /var/www/html

#COPY neo4j-gremlin-plugin-2.1-SNAPSHOT.jar .
#RUN cp neo4j-gremlin-plugin-2.1-SNAPSHOT.jar /var/lib/neo4j/plugins/gremlin-plugin
#get navex
COPY chess-navex/ ./chess-navex


RUN mkdir results
COPY load_app_to_neo4j.sh .
RUN chmod 755 load_app_to_neo4j.sh
RUN ./load_app_to_neo4j.sh -r ./results -n MyApp2 -a xss

COPY start.sh .
EXPOSE 7474
 

RUN chmod 755 start.sh

RUN pip3 install pyzmq==18.1.0
RUN pip3 install protobuf==3.7.1

#RUN cd ../chess_messages && python3 -m pip install --no-index --no-deps .
#RUN cd ../chess_integration_framework && python3 -m pip install --no-index --no-deps .

#RUN python3 -m pip install --no-index --no-deps .
#RUN python3 -m pip install --no-index --no-deps .
ENV JAVA_HOME=""
CMD ./start.sh

