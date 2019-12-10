pipeline {
  agent {
    kubernetes {
      label 'testpod'
      yaml """
apiVersion: v1
kind: Pod
metadata:
  labels:
    some-label: some-label-value
spec:
  containers:
    - name: gcloud-kubectl-docker
      image: claranet/gcloud-kubectl-docker:latest
      command:
      - cat
      tty: true
    - name: docker
      image: docker:latest
      command:
      - cat
      tty: true
      env:
      - name: POD_IP
        valueFrom:
          fieldRef:
            fieldPath: status.podIP
      - name: DOCKER_HOST
        value: tcp://localhost:2375
    - name: maven
      image: maven:3.5.2
      command:
      - cat
      tty: true
    - name: helm
      image: alpine/helm:2.13.1
      command:
      - cat
      tty: true
    - name: dind
      image: docker:18.05-dind
      securityContext:
        privileged: true
      volumeMounts:
        - name: dind-storage
          mountPath: /var/lib/docker
  volumes:
    - name: dind-storage
      emptyDir: {}
"""
    }
  }
  stages {
    stage('Use last tag commit if present ') {
      steps {
        container('gcloud-kubectl-docker') {
          script {
            withCredentials([sshUserPrivateKey(credentialsId: 'devopsa3', keyFileVariable: 'GC_KEY')]) {
              sh("gcloud auth activate-service-account jenkins@devopsa3.iam.gserviceaccount.com --key-file=${GC_KEY}")
              sh("gcloud container clusters get-credentials devopsa3cluster --zone us-central1-a --project devopsa3")
              sh("kubectl cluster-info")
            }
          }
        }
      }
    }

    stage('Run maven') {
      steps {
        container('maven') {
          sh 'mvn -Dmaven.test.failure.ignore clean package'
        }
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
        steps {
            container('docker') {
                script {
                    IMAGE_ID = sh (script: 'docker build . -q --build-arg GREETING', returnStdout: true).trim()
                }
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
                steps {
                    container('docker') {
                        script{
                            sh """
                                docker network create --driver=bridge curltest
                                docker run -d --net=curltest --name='dropw-test' ${IMAGE_ID}
                            """
                        }
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
                        steps {
                            container('docker') {
                                script {
                                    HTTP_RESPONSE_CODE_0 = sh (script: 'docker run -i --net=curltest tutum/curl \
                                        curl -s http://dropw-test:8080/hello-world | awk \'{print $(NF-1)}\'', returnStdout: true).trim()
                                    if (!"${HTTP_RESPONSE_CODE_0}" == "${IMAGE_TAG}") {
                                        throw new Exception("Testing response app tag failure!")
                                    }
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
                        steps {
                            container('docker') {
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
            container('docker') {
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

    stage('Lint helm chart') {
        when { not { changeRequest() } }
            steps {
                container('helm') {
                    sh "helm lint ${CHART_DIR}"
                }
            }
        post {
            success{
                println "Helm chart successfully checked"
            }
            failure{
                println "Error checking helm chart"
            }
        }
    }

    stage('Deploy to k8s') {
        when { allOf { branch 'master'; not { changeRequest() } } }
        steps {
            container('helm') {
                sh "helm init --client-only"
                withCredentials([file(credentialsId: "${CLUSTER_KUBECONFIG}", variable: 'kubeconfig')]) {
                    sh """
                        cat $kubeconfig > kubeconfig
                        helm upgrade ${HELM_RELEASE} ${CHART_DIR} --install --kubeconfig kubeconfig --set image.repository=${IMAGE_NAME} --set image.tag=${IMAGE_TAG} --debug --wait
                    """
                }
            }
        }
        post {
            success{
                println "New release was successfully deployed"
            }
            failure{
                println "Error deploying the chart"
            }
        }
    }

  }
}
