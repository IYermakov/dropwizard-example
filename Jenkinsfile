pipeline {
  agent any
  options {
    timestamps()
  }
  environment {
    DOCKERHUB_SERVER = 'https://index.docker.io/v1/'
    IMAGE_NAME = 'notregistered/dropw'
    IMAGE_TAG = sh (script: 'git describe --tags --always', returnStdout: true).trim()
  }
  stages {
    stage('Use last tag commit if present ') {
      when { buildingTag() }
      steps {
        script {
            IMAGE_TAG = "${TAG_NAME}"
        }
      }
    }

    stage('Run maven') {
      agent {
        docker {
          image 'maven:latest'
        }
      }
      steps {
          sh 'mvn -Dmaven.test.failure.ignore clean package'
      }
      post {
        success{
            println "Maven build is OK"
        }
        failure{
            println "Something wrong with maven build"
        }
      }
    }

    stage('Docker image build') {
      environment {
        GREETING="${IMAGE_TAG}"
      }
      agent {
        docker {
          image 'docker:dind'
        }
      }
      steps {
        script {
          IMAGE_ID = sh (script: 'docker build . -q --build-arg GREETING', returnStdout: true).trim()
        }
      }
      post {
        success{
            println "Docker build complete"
            println "Image ID is ${IMAGE_ID}"
            println "Application tag is ${GREETING}"
        }
        failure{
            println "Docker build failure"
        }
    }
    }

    stage('Docker testing') {
        stages {
            stage('Run image for testing') {
      agent {
        docker {
          image 'docker:dind'
        }
      }
                steps {
                  script{
                    sh """
                        docker network create --driver=bridge curltest
                        docker run -d --net=curltest --name='dropw-test' ${IMAGE_ID}
                       """
                    }
                }
                post {
                    success{
                        println "App 'dropw-test' is running in bridge network 'curltest'"
                    }
                    failure{
                        println "Error running app"
                    }
                }
            }
            stage('Tests:') {
                parallel {
                    stage('Test app response tag') {
                        agent {
                          docker {
                            image 'dind:latest'
                          }
                        }
                        steps {
                                script {
                                    HTTP_RESPONSE_CODE_0 = sh (script: 'docker run -i --net=curltest tutum/curl \
                                        curl -s http://dropw-test:8080/hello-world | awk \'{print $(NF-1)}\'', returnStdout: true).trim()
                                    if (!"${HTTP_RESPONSE_CODE_0}" == "${IMAGE_TAG}") {
                                        throw new Exception("Testing response app tag failure!")
                                    }
                                }
                        }
                        post {
                            success{
                                println "Testing reponse app tag was successful"
                            }
                            failure{
                                println "Error testing response app tag"
                            }
                        }
                    }
                    stage('Test read and write') {
      agent {
        docker {
          image 'dind:latest'
        }
      }
                        steps {
                                script {
                                    HTTP_RESPONSE_CODE_1 = sh (script: 'docker run -i --net=curltest tutum/curl \
                                        curl -o /dev/null -I -s -w "%{http_code}" http://dropw-test:8080/hello-world', returnStdout: true).trim()
                                    HTTP_RESPONSE_CODE_2 = sh (script: 'docker run -i --net=curltest tutum/curl \
                                        curl -H "Content-Type: application/json" -o /dev/null -s -w "%{http_code}" -X POST -d \'{"fullName":"Test Person","jobTitle":"Test Title"}\' http://dropw-test:8080/people', returnStdout: true).trim()
                                    HTTP_RESPONSE_CODE_3 = sh (script: 'docker run -i --net=curltest tutum/curl \
                                        curl -o /dev/null -I -s -w "%{http_code}" http://dropw-test:8080/people/1', returnStdout: true).trim()
                                    if (!"${HTTP_RESPONSE_CODE_1}" == 200 || !"${HTTP_RESPONSE_CODE_2}" == 200 || !"${HTTP_RESPONSE_CODE_3}" == 200) {
                                        println "Raising failure status"
                                        throw new Exception("Testing read and write failure!")
                                    }
                            }
                        }
                        post {
                            success{
                                println "Testing successful."
                            }
                            failure{
                                println "Testing is not completed:"
                                println "HTTP response for GET hello-world page is - ${HTTP_RESPONSE_CODE_1}"
                                println "HTTP response for POST test person is - ${HTTP_RESPONSE_CODE_2}"
                                println "HTTP response for GET test person - ${HTTP_RESPONSE_CODE_3}"
                            }
                        }
                    }
                }
            }
        }
    }

    stage('Docker tag image and push to repository.') {
        when { not { changeRequest() } }
        steps {
                script {
                    if ("${GIT_BRANCH}"!='master') {
                        IMAGE_TAG = "${GIT_BRANCH}-${IMAGE_TAG}"
                    }
                }
                    withCredentials([[$class: 'UsernamePasswordMultiBinding',
                        credentialsId: 'dockerhub',
                        usernameVariable: 'DOCKER_USER',
                        passwordVariable: 'DOCKER_PASSWORD']]) {
                            sh """
                                docker login -u ${DOCKER_USER} -p ${DOCKER_PASSWORD} ${DOCKERHUB_SERVER}
                                docker tag ${IMAGE_ID} ${IMAGE_NAME}:${IMAGE_TAG}
                                docker push ${IMAGE_NAME}:${IMAGE_TAG}
                            """
                       }
            }
        post {
            success{
                println "Image was successfully pushed to repo - ${IMAGE_NAME}:${IMAGE_TAG}"
            }
            failure{
                println "Error pushing docker image"
            }
        }
    }

  }
}
