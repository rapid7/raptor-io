worker_processes 20
timeout 30
preload_app true


# ab -n 200 -c 10 http://127.0.0.1:9292/sleep