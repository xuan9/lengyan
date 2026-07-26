plugins {
    id("androidx.room")
    id("com.google.devtools.ksp")
}

room {
    schemaDirectory("$projectDir/schemas")
}
