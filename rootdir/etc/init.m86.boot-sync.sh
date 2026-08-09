#!/system/bin/sh

# Keep logpersistd's /data output durable without pstore. Do not write a custom
# heartbeat: even permissive cache_file denials are fed back into logd and can
# perturb this old kernel during the framework's busiest startup phase.
while true; do
  sync
  sleep 1
done
