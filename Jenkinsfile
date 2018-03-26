pipeline {
  agent any
  stages {
    stage('Sanity Check') {
      parallel {
        stage('format.sh') {
          steps {
            sh 'shellcheck --version'
            sh 'shellcheck --exclude=SC2086 format.sh'
          }
        }
        stage('lint.sh') {
          steps {
            sh 'shellcheck --version'
            sh 'shellcheck --exclude=SC2010,SC2086 lint.sh'
          }
        }
        stage('sync.sh') {
          steps {
            sh 'shellcheck --version'
            sh 'shellcheck --exclude=SC2029,SC2086 sync.sh'
          }
        }
        stage('update_repo.sh') {
          steps {
            sh 'shellcheck --version'
            sh 'shellcheck update_repo.sh'
          }
        }
      }
    }
  }
}
