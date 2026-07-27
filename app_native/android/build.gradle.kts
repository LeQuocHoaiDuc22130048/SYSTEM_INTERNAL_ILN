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

subprojects {
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        val targetCompat = (project.extensions.findByName("android") as? com.android.build.gradle.BaseExtension)
            ?.compileOptions
            ?.targetCompatibility
            ?: (project.extensions.findByName("java") as? org.gradle.api.plugins.JavaPluginExtension)
            ?.targetCompatibility

        if (targetCompat != null) {
            val targetStr = when (targetCompat) {
                JavaVersion.VERSION_1_8 -> "1.8"
                JavaVersion.VERSION_11 -> "11"
                JavaVersion.VERSION_17 -> "17"
                JavaVersion.VERSION_21 -> "21"
                else -> targetCompat.toString()
            }
            compilerOptions {
                jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.fromTarget(targetStr))
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
