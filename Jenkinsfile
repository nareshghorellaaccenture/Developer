pipeline {
    agent any

    environment {
        SF_INSTANCE_URL = 'https://orgfarm-b89fecc624-dev-ed.develop.my.salesforce.com'
        SF_ALIAS = 'devorg'
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }       

        stage('Authenticate Salesforce') {
            steps {
                withCredentials([
                    file(
                        credentialsId: 'salesforce-jwt-key',
                        variable: 'SF_JWT_KEY'
                    ),
                    string(
                        credentialsId: 'salesforce-client-id',
                        variable: 'SF_CLIENT_ID'
                    ),
                    string(
                        credentialsId: 'salesforce-username',
                        variable: 'SF_USERNAME'
                    )
                ]) {
                    bat '''
                        sf org login jwt ^
                          --client-id "%SF_CLIENT_ID%" ^
                          --jwt-key-file "%SF_JWT_KEY%" ^
                          --username "%SF_USERNAME%" ^
                          --instance-url "%SF_INSTANCE_URL%" ^
                          --alias "%SF_ALIAS%"
                    '''
                }
            }
        }

        stage('Verify Authentication') {
            steps {
                bat '''
                    sf org display --target-org "%SF_ALIAS%"
                '''
            }
        }

        stage('Validate Salesforce Deployment') {
            steps {
                bat '''
                    sf project deploy validate ^
                      --source-dir force-app ^
                      --target-org "%SF_ALIAS%" ^
                      --test-level RunLocalTests ^
                      --wait 30
                '''
            }
        }

        stage('Deploy to Salesforce') {
            steps {
                bat '''
                    sf project deploy start ^
                      --source-dir force-app ^
                      --target-org "%SF_ALIAS%" ^
                      --test-level RunLocalTests ^
                      --wait 30
                '''
            }
        }
    }

    post {
        success {
            echo 'Salesforce deployment completed successfully.'
        }

        failure {
            echo 'Salesforce deployment failed. Check the Jenkins console logs.'
        }

        always {
            echo 'Salesforce Jenkins pipeline completed.'
        }
    }
}