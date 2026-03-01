setup() {
  load setup_suite
}

@test "pen status works after install" {
  run_as_sudo_user "$TEST_USER" "$TEST_PROJECT/install.sh"

  run pen_run status
  [ "$status" -eq 1 ]
  [[ "$output" == *"Pen not running"* ]]
}
