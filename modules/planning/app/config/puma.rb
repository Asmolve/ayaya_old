threads_count = ENV.fetch("RAILS_MAX_THREADS", 3)
threads threads_count, threads_count

bind "tcp://0.0.0.0:#{ENV.fetch("PORT", 3000)}"
workers Integer(ENV.fetch("WEB_CONCURRENCY", 2)) if ENV.fetch("RAILS_ENV", "development") == "production"
plugin :tmp_restart unless ENV.fetch("RAILS_ENV", "development") == "production"
pidfile ENV["PIDFILE"] if ENV["PIDFILE"]
