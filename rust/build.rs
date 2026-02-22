fn main() {
    // flutter_rust_bridge code generation is handled separately
    // This build script is for pre-build tasks
    println!("cargo:rerun-if-changed=src/api.rs");
}
