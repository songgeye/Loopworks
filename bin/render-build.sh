set -o errexit

bundle install
bin/rails db:prepare