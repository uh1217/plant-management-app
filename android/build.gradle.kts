allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// 빌드 결과물이 저장될 위치를 지정합니다.
rootProject.layout.buildDirectory.value(rootProject.layout.projectDirectory.dir("../build"))

subprojects {
    val newBuildDir = rootProject.layout.buildDirectory.dir(project.name)
    project.layout.buildDirectory.value(newBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}