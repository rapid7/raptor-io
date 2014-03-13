worker_processes 5
timeout 10
preload_app true


# ab -n 200 -c 10 http://127.0.0.1:9292/sleep