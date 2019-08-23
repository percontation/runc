#!/usr/bin/env bats

load helpers

function setup() {
  teardown_busybox
  setup_busybox
}

function teardown() {
  teardown_busybox
}

@test "runc delete" {
  # run busybox detached
  runc run -d --console-socket $CONSOLE_SOCKET test_busybox
  [ "$status" -eq 0 ]

  # check state
  testcontainer test_busybox running

  runc kill test_busybox KILL
  [ "$status" -eq 0 ]
  # wait for busybox to be in the destroyed state
  retry 10 1 eval "__runc state test_busybox | grep -q 'stopped'"

  # delete test_busybox
  runc delete test_busybox
  [ "$status" -eq 0 ]

  runc state test_busybox
  [ "$status" -ne 0 ]
}

@test "runc delete --force" {
  # run busybox detached
  runc run -d --console-socket $CONSOLE_SOCKET test_busybox
  [ "$status" -eq 0 ]

  # check state
  testcontainer test_busybox running

  # force delete test_busybox
  runc delete --force test_busybox

  runc state test_busybox
  [ "$status" -ne 0 ]
}

@test "runc delete --force ignore not exist" {
  runc delete --force notexists
  [ "$status" -eq 0 ]
}

@test "runc delete with frozen cgroups" {
  # edit config.json so cgroups are writeable
  jq '.mounts = [(.mounts[] | select(.destination == "/sys/fs/cgroup").options -= ["ro"])]' config.json > config.json.tmp && mv config.json.tmp config.json

  # run busybox detached
  runc run -d --console-socket $CONSOLE_SOCKET test_busybox
  [ "$status" -eq 0 ]

  # check state
  testcontainer test_busybox running

  # attach to a container, spawn a shell and freeze its cgroup.  Be sure the frozen process is backgrounded otherwise runc exec hangs.  Sleep 1 so that the background
  # process doesn't get killed before it's done executing.
  runc exec test_busybox sh -c "cd /sys/fs/cgroup/freezer && sh -c 'mkdir dummy && echo "'$$'" > dummy/cgroup.procs && echo FROZEN > dummy/freezer.state' & sleep 1"

  runc kill test_busybox KILL
  [ "$status" -eq 0 ]
  # wait for busybox to be in the destroyed state
  retry 10 1 eval "__runc state test_busybox | grep -q 'stopped'"

  # delete test_busybox
  runc delete test_busybox
  [ "$status" -eq 0 ]

  runc state test_busybox
  [ "$status" -ne 0 ]
}
