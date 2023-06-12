require 'bundler/setup'
require 'bundler/gem_tasks'

task :default => "test:units"

task :test => "test:all"

IMAGES = %w(ubuntu:12.04 ubuntu:14.04 ubuntu:16.04 ubuntu:18.04 debian:7 debian:8 debian:squeeze centos:centos7)

namespace :test do
  task :setup do
    known_images = `docker images --format '{{.Repository}}:{{.Tag}}'`.chomp.split("\n")
    IMAGES.each do |img|
      sh "docker pull #{img}" unless known_images.include?(img)
    end
  end

  task :units do
    sh "rspec"
  end

  task :all => :setup do
    sh "FPM_FRY_DOCKER=yes rspec"
  end
end
