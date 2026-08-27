allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Os SDKs nativos do Firebase expõem tipos anotados com checker-qual /
// error-prone (via Guava). O compilador Kotlin de plugins como o firebase_auth
// falha se essas anotações não estiverem no classpath. Disponibiliza em todos
// os módulos Android.
subprojects {
    listOf("com.android.library", "com.android.application").forEach { pid ->
        plugins.withId(pid) {
            dependencies {
                add("compileOnly", "org.checkerframework:checker-qual:3.48.4")
                add("compileOnly", "com.google.errorprone:error_prone_annotations:2.36.0")
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
