fn main() {
    println!("cargo::rerun-if-changed=../tests/cases");
    println!("cargo::rerun-if-env-changed=TEST_SUITE_DIR");
}
