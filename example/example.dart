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