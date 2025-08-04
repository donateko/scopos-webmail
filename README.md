# Mailbux Mail Client


   <p align="center">
    <a href="https://github.com/linagora/tmail-flutter/">Forked from Twake Mail</a>
  </p>

---

  

This project aims at providing a multi-platform mobile email application, running the [JMAP protocol](https://jmap.io/) and will also deliver additional 
features to the [Mailbux](https://mailbux.com).


## Build app
1. Go to root folder of project
2. Run `scripts/prebuild.sh` script
```
/bin/bash scripts/prebuild.sh
```
3. Build
+ iOS:
```
flutter build ios 
```

+ Android:
```
flutter build apk
```

+ Web:

change `SERVER_URL` in `env.file` with your JMAP server
```
SERVER_URL=http://your-jmap-server.domain
```
then run: 
```
flutter build web
```

#### Edit the environment file before the build

Edit the `env.file` by replacing the default value of `SERVER_URL` to the one pointing to your JMAP backend server.


