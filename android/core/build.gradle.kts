plugins {
    alias(libs.plugins.kotlin.jvm)
}

kotlin {
    jvmToolchain(17)
}

// `core` es Kotlin puro (sin Android ni coroutines): se puede compilar y testear
// en cualquier JVM con `tools/verify_core.sh`.
