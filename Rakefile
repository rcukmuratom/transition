#!/usr/bin/env rake
# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require File.expand_path('config/application', __dir__)

Rails.application.load_tasks

task(:default).clear
task default: [:spec, :cucumber, 'jasmine:ci', :lint, :check_for_bad_time_handling]
