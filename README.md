[![](https://img.shields.io/badge/fluent-design-blue?style=flat-square&color=gray&labelColor=0078D7)](https://github.com/bdlukaa/fluent_ui) 

## WTNews

Receive War Thunder news on your Windows PC.

---

### Usage

Usage of the application is pretty simple, just install the app using the already uploaded releases. Run the `installer.bat` and let the process of installing my certificate be done, then install the MSIX package.

This application uses VonAssistant, my private utility which handles updates, runs at startups, etc.

### Build the project

Requirements:

1.  Flutter SDK
2.  [Windows Setup](https://docs.flutter.dev/get-started/install/windows#windows-setup)

To build your fork of WTNews, clone/fork this repository:

```plaintext
git clone https://github.com/Vonarian/wtnews.git
cd wtnews
```

Now you are in the project's directory, run the following command(s) to build this project for Windows:

```plaintext
flutter pub get
flutter build windows
```

Optionally, you can use [Puro](https://puro.dev). This allows developers to improve disk/internet usage.

**Note**: This application uses Sentry and Firebase. Secret information for these services is not included in the repository, you need to either remove the dependencies or make your own configurations.

### War Thunder Forum

You can check out the application's forum page [here](https://forum.warthunder.com/index.php?/topic/549057-wtnews-get-notified-of-war-thunder-news/).

## Contributions

Please head to the [Issues](https://github.com/Vonarian/wtnews/issues) section and file any bugs and improvements you have in mind :)