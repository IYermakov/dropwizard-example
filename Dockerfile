FROM openjdk:8-jre-alpine
WORKDIR /
ADD target/dropwizard-example-0.0.1-SNAPSHOT.jar dropwizard.jar
ADD example.yml example.yml
EXPOSE 8080
CMD java -jar dropwizard.jar db migrate example.yml
CMD java -Xmx750M -jar dropwizard.jar server example.yml
