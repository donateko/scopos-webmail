# Mailbux Mail Client 
⚠️ **Note**  
 This is only the email client! You will also need the mail server, which we provide at the lowest rate in the world for unlimited accounts  
 *(starting at only $3.95 with unlimited email accounts).*  
 
👉 Find out more here: [MailWish – Unlimited Business Email Hosting](https://mailwish.com)


---


This project aims at providing a multi-platform mobile email application, running the [JMAP protocol](https://jmap.io/) and will also deliver additional 
features to the [Mailbux Cross Email Client](https://mailbux.com) built for [Mailwish - Unlimited business email hosting](https://mailwish.com) and forked from [Tmail by linagora](https://github.com/linagora/tmail-flutter).

> ⚠️ **Important Notice**  
> This email client has been heavily customized to work specifically with the **[MailWish/MailBux Business Email Hosting](https://mailwish.com)**.  
>
> - We **do not provide support** for customization, third-party code changes, or bug fixes.  
> - This version is released **as-is**, intended for developers who wish to:  
>   - Contribute improvements through commits.  
>   - Adjust branding for their business (if using MailWish as the backend).
>   - The login page at https://auth.mailbux.com
 is not customizable. You will need to update the email client to support self-login without OIDC, plain JMAP login (Developer required).
>
> If you are running the **MailWish Business Email Hosting**, you may use this client as your front end.  
> Otherwise, please note that compatibility and support are not guaranteed.



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


