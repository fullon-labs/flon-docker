def notifyTelegram(String channel, String reference, String chatId) {
    def message = """flon-core ${channel}: ${currentBuild.currentResult}
Ref: ${reference ?: 'unspecified'}
Build: ${env.JOB_NAME} #${env.BUILD_NUMBER}
${env.BUILD_URL}"""

    catchError(buildResult: 'SUCCESS', stageResult: 'SUCCESS',
               message: 'Telegram notification failed') {
        // Queue cancellation can reach post actions before the build agent has a workspace.
        timeout(time: 1, unit: 'MINUTES') {
            node('master') {
                withCredentials([string(credentialsId: 'tgbot', variable: 'TG_BOT')]) {
                    withEnv(["TELEGRAM_CHAT_ID=${chatId}", "TELEGRAM_MESSAGE=${message}"]) {
                        sh(label: 'Notify Telegram', script: '''
                            set +x
                            printf 'url = "https://api.telegram.org/bot%s/sendMessage"\\n' "$TG_BOT" |
                                curl --config - --silent --show-error --fail --max-time 15 \\
                                    --output /dev/null \\
                                    --data-urlencode "chat_id=$TELEGRAM_CHAT_ID" \\
                                    --data-urlencode "text=$TELEGRAM_MESSAGE"
                        ''')
                    }
                }
            }
        }
    }
}

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
            description: 'flon-core branch or commit to compile (for example: develop or a commit SHA)',
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
                    echo 'Build-only policy: registry credentials, login, and image push are disabled.'
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
        always {
            script {
                notifyTelegram('development build', params.FULLON_REF, '-4127968707')
            }
        }
        success {
            echo "Build completed. Image remains local on a3: ${env.OUTPUT_IMAGE}"
        }
        failure {
            echo 'Build failed before any registry push was attempted.'
        }
    }
}
