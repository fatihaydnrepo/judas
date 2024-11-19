pipeline {
    agent any
    
    environment {
        HELM_RELEASE = 'demo-app'
        NAMESPACE = 'demo'
    }
    
    stages {
        stage('Deploy') {
            steps {
                sh """
                    helm upgrade ${HELM_RELEASE} ./helm-charts/app \
                    --install \
                    --namespace=${NAMESPACE} \
                    --create-namespace \
                    --set image.tag=latest \
                    --wait \
                    --timeout 5m
                """
            }
        }
        
        stage('Verify') {
            steps {
                sh """
                    kubectl wait --for=condition=ready pod \
                    -l app.kubernetes.io/name=${HELM_RELEASE} \
                    -n ${NAMESPACE} \
                    --timeout=300s
                """
            }
        }
    }
    
    post {
        success {
            echo 'Helm deployment successful!'
        }
        failure {
            echo 'Helm deployment failed!'
        }
    }
}
