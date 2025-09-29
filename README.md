# UnityAndroidLibrary

Export Unity Gradle Project

- Android player setting, under Android application entry points, uncheck GameActivity and check Activity

- Copy unityLibrary and shared folder from exported folder to the android project root folder which has folders like (app, gradle, .kotlin)

- make sure the root setting.gradle has below lines or add them at last

```
    include(":unityLibrary")
    project(":unityLibrary").projectDir = file("unityLibrary")
```

- unityLibrary/build.gradle replace androidResources block with below code

```
androidResources {
        def base = ['unity3d','ress','resource','obb','bundle','unityexp']
        def extra = []
        if (project.ext.has('unityStreamingAssets') && project.ext.unityStreamingAssets) {
            extra = project.ext.unityStreamingAssets
                    .toString()
                    .split(',')
                    .collect { it.trim().replaceFirst(/^\\./,'') }
                    .findAll { it }
        }
        noCompress = (base + extra)
        ignoreAssetsPattern = "!.svn:!.git:!.ds_store:!*.scc:!CVS:!thumbs.db:!picasa.ini:!*~"
}
```

- app/build.gradle add unityLibrary as dependency

```
    implementation(project(":unityLibrary"))
```
