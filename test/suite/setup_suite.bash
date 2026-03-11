source "$(dirname "${BASH_SOURCE[0]}")/test_helper.bash"

setup_suite() {
  sudo "$PEN_REPO/install.sh"
}
