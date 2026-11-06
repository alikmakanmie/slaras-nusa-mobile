allprojects {
    repositories {
        // Repo Maven lokal (offline VM Hatch) — aktif bila env LOCAL_MAVEN_REPO
        // diset; diabaikan di CI/mesin normal (pakai google()/mavenCentral()).
        val localRepo = System.getenv("LOCAL_MAVEN_REPO")
        if (localRepo != null) {
            maven { url = uri(localRepo) }
        }
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
