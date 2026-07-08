allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    afterEvaluate {
        project.extensions.findByName("android")?.let { androidExt ->
            try {
                val getNs = androidExt.javaClass.getMethod("getNamespace")
                val ns = getNs.invoke(androidExt) as? String
                if (ns.isNullOrEmpty()) {
                    val manifest = file("src/main/AndroidManifest.xml")
                    if (manifest.exists()) {
                        val packageName = Regex("package=\"([^\"]+)\"").find(manifest.readText())?.groupValues?.get(1)
                        if (packageName != null) {
                            androidExt.javaClass.getMethod("setNamespace", String::class.java).invoke(androidExt, packageName)
                        }
                    }
                }
            } catch (e: Exception) {}
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
