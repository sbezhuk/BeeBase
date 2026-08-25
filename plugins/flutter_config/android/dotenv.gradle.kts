import org.gradle.api.DomainObjectCollection

fun getCurrentFlavor(): String {
    val pattern = Regex("(?:.*:)*[a-z]+([A-Z][A-Za-z0-9]+)")
    var flavor = ""

    gradle.startParameter.taskNames.any { name ->
        val match = pattern.find(name)
        if (match != null) {
            flavor = match.groupValues[1].lowercase()
        }
        match != null
    }

    return flavor
}

fun loadDotEnv(flavor: String = getCurrentFlavor()) {
    var envFile = ".env"

    @Suppress("UNCHECKED_CAST")
    val envConfigFiles = if (project.hasProperty("envConfigFiles")) {
        project.property("envConfigFiles") as Map<String, String>
    } else {
        null
    }

    if (System.getenv("ENVFILE") != null) {
        envFile = System.getenv("ENVFILE")
    } else if (System.getProperty("ENVFILE") != null) {
        envFile = System.getProperty("ENVFILE")
    } else if (envConfigFiles != null) {
        envConfigFiles.entries.any { (key, value) ->
            val matches = flavor.startsWith(key)
            if (matches) {
                envFile = value
            }
            matches
        }
    } else if (project.hasProperty("defaultEnvFile")) {
        envFile = project.property("defaultEnvFile") as String
    }

    val env = mutableMapOf<String, String>()
    println("Reading env from: $envFile")

    var f = File("${project.rootDir}/../$envFile")
    if (!f.exists()) {
        f = File(envFile)
    }

    if (f.exists()) {
        val lineRegex = Regex("""^\s*(?:export\s+|)([\w\d.\-_]+)\s*=\s*['"]?(.*?)?['"]?\s*$""")
        f.forEachLine { line ->
            val match = lineRegex.matchEntire(line)
            if (match != null && match.groupValues.size == 3) {
                env[match.groupValues[1]] = match.groupValues[2].replace("\"", "\\\"")
            }
        }
    } else {
        println("**************************")
        println("*** Missing .env file ****")
        println("**************************")
    }

    project.extra.set("env", env)
}

loadDotEnv()

@Suppress("UNCHECKED_CAST")
fun currentEnv(): Map<String, String> = project.extra["env"] as Map<String, String>

fun applyEnv(target: Any, env: Map<String, String>) {
    target.withGroovyBuilder {
        env.forEach { (k, v) ->
            val escaped = v.replace("%", "\\u0025")
            "buildConfigField"("String", k, "\"$v\"")
            "resValue"("string", k, escaped)
        }
    }
}

val android = extensions.getByName("android")

android.withGroovyBuilder {
    applyEnv(getProperty("defaultConfig"), currentEnv())
}

tasks.whenTaskAdded {
    if (project.hasProperty("envConfigFiles")) {
        @Suppress("UNCHECKED_CAST")
        val envConfigFiles = project.property("envConfigFiles") as Map<String, String>
        envConfigFiles.keys.forEach { envConfigName ->
            if (name.lowercase() == "generate" + envConfigName + "buildconfig") {
                @Suppress("UNCHECKED_CAST")
                val applicationVariants = android.withGroovyBuilder {
                    getProperty("applicationVariants")
                } as DomainObjectCollection<Any>

                applicationVariants.all {
                    val variant = this
                    val variantConfigString = variant.withGroovyBuilder { getProperty("name") } as String
                    if (envConfigName.contains(variantConfigString.lowercase())) {
                        loadDotEnv(envConfigName)
                        applyEnv(variant, currentEnv())
                    }
                }
            }
        }
    }
}
