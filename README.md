 # G-Earth Dart Package

 [G-Earth](https://github.com/sirjonasxx/G-Earth) extension interface for Dart.

|             | Linux | macOS  | Windows     |
|-------------|-------|--------|-------------|
| **Support** | Any   | Any    | Any         |

## Getting started

1. <a href="https://docs.flutter.dev/get-started/install" target="_blank"><button class="button button-primary" style="color:#e8f0fe;background-color:#1a73e8;line-height:31px;border-radius:5px">Install Flutter SDK</button></a>

2. Create a new Flutter project on the terminal

    `flutter create <project_name>`

3. Add the G-Earth package to your project by adding the following line as a dependency in your **pubspec.yaml** file:
    ```
    gearth:
      git:
        url: https://github.com/asyzx/G-Earth-Dart
        ref: main
    ```


## Usage

To use this package, add `gearth` as a dependency in your pubspec.yaml file.

Here are small examples that show you how to use.

```dart
// This is a template extension with the minimal amount of code to connect with G-Earth

import 'package:gearth/hpacket.dart';
import 'package:gearth/extension.dart';

final extensionInfo = ExtensionInfo(
  title:"Dart Extension",
  description:"dart gearth extension test",
  version:"1.0",
  author:"asyzx"
);

void main(){
  final ext = Extension(extensionInfo);
  ext.start(); // default port=9092
}
```

### Packet injection

```dart
// sending packets to the server
ext.sendToServer(HPacket('RoomUserAction', 1));

// sending packets from the client
ext.sendToClient(HPacket('MoveAvatar', 1, 7));
```

### Intercepting packets


```dart
// intercept & parse specific packets
void on_walk(HMessage message){
    var x = message.packet.readInt();
    var y = message.packet.readInt();
    print("Walking to $x, $y");
}

void on_speech(HMessage message){
    var text = message.packet.readString();
    var color = message.packet.readInt();
    var index = message.packet.readInt();
    message.isBlocked = (text == 'blocked');  // block packet 
    print("User said: $text");
}
    

ext.intercept(Direction.TO_SERVER, 'RoomUserWalk', on_walk);
ext.intercept(Direction.TO_SERVER,'RoomUserTalk', on_speech);
```
<!-- [Click here]() for more examples. -->

## Additional information

Join the G-Earth [Discord server](https://discord.com/invite/AVkcF8y)


