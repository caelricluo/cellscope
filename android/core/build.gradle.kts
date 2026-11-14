plugins { kotlin("jvm") }
kotlin { compilerOptions { jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17) } }
java { sourceCompatibility = JavaVersion.VERSION_17; targetCompatibility = JavaVersion.VERSION_17 }
dependencies { testImplementation("junit:junit:4.13.2") }
tasks.register<JavaExec>("diagnose") {
    classpath=sourceSets.main.get().runtimeClasspath
    mainClass.set("com.cellscope.core.DiagnosticsKt")
    args(providers.gradleProperty("image").getOrElse("image.pgm"),providers.gradleProperty("mode").getOrElse("CORNERS"),providers.gradleProperty("sensitivity").getOrElse("0.55"))
}
