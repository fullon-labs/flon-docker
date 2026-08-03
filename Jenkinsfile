pipeline {
    agent {
        label 'a3'
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '20'))
        disableConcurrentBuilds()
        skipDefaultCheckout(true)
        timestamps()
        timeout(time: 120, unit: 'MINUTES')
    }

    parameters {
        string(
            name: 'FULLON_REF',
            defaultValue: 'develop',
            description: 'flon-core branch or tag to compile (for example: develop or v0.6.6)',
            trim: true
        )
    }

    environment {
        DOCKER_IMG = 'floncore/funod'
        FLON_LOAD_USER_ENV = 'false'
        MODE = 'git'
        NODE_IMG_HEADER = 'local/'
        REPO = 'https://github.com/fullon-labs/flon-core.git'
    }

    stages {
        stage('Checkout build tools') {
            steps {
                git branch: 'main', url: 'https://github.com/fullon-labs/flon-docker.git'
            }
        }

        stage('Resolve build inputs') {
            steps {
                script {
                    def sourceRef = params.FULLON_REF?.trim()

                    if (!sourceRef || !(sourceRef ==~ /[A-Za-z0-9][A-Za-z0-9._\/-]*/)) {
                        error("Invalid FULLON_REF: ${sourceRef}")
                    }

                    env.FULLON_BRANCH = sourceRef
                    env.FULLON_VERSION = "ci-${env.BUILD_NUMBER}"
                    env.OUTPUT_IMAGE = "${env.NODE_IMG_HEADER}${env.DOCKER_IMG}:${env.FULLON_VERSION}"
                    currentBuild.description = "${sourceRef} -> ${env.OUTPUT_IMAGE}"

                    echo "Source ref: ${env.FULLON_BRANCH}"
                    echo "Local output image: ${env.OUTPUT_IMAGE}"
                    echo 'Build-only policy: registry login and image push are disabled.'
                }
            }
        }

        stage('Compile flon-core') {
            steps {
                dir('flon.chain/node-build') {
                    sh '''
                        set -eu
                        mkdir -p "${WORKSPACE}/.jenkins-home"
                        HOME="${WORKSPACE}/.jenkins-home" ./build.sh
                        docker image inspect "${OUTPUT_IMAGE}" >/dev/null
                    '''
                }
            }
        }
    }

    post {
        success {
            echo "Build completed. Image remains local on a3: ${env.OUTPUT_IMAGE}"
        }
        failure {
            echo 'Build failed before any registry push was attempted.'
        }
    }
}
