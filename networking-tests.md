```
lin node -> win pod
lin node -> lin pod
lin node -> win svc
lin node -> lin svc

win node -> win pod
win node -> lin pod
win node -> lin svc
win node -> win svc  # DOESN'T WORK

lin pod -> lin pod
lin pod -> win pod
lin pod -> lin svc (with dns)
lin pod -> win svc (with dns)

win pod -> lin pod
win pod -> win pod
win pod -> lin svc (with dns)
win pod -> win svc (with dns)

lin pod -> internet (with dns)
win pod -> internet (with dns)

external -> node-port svc via controlplane
external -> node-port svc via win-worker  # DOESN'T WORK
```