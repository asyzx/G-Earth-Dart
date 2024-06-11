import 'dart:typed_data';
import 'dart:convert';

import 'extension.dart';


enum Direction
{
	toClient,
  toServer;
}

class IncomingMessages
{
	static const int onDoubleClick = 1;
	static const int infoRequest = 2;
	static const int packetIntercept = 3;
	static const int flagsCheck = 4;
	static const int connectionStart = 5;
	static const int connectionEnd = 6;
	static const int packetToStringResponse = 20;
	static const int stringToPacketResponse = 21;
	static const int init = 7;
}

class OutgoingMessages
{
	static const int extensionInfo = 1;
	static const int manipulatedPacket = 2;
	static const int requestFlags = 3;
	static const int sendMessage = 4;
	static const int packetToStringRequest = 20;
	static const int stringToPacketRequest = 21;
	static const int extensionConsoleLog = 98;
}


class HMessage{

  HPacketView gearthPacket;
  late Direction _direction;

  final int _isBlockedIndex = 10;
  late int _isEditedIndex;
  late int packetOffsetInBytes;
  late int packetNumberStart, packetNumberEnd;


  late HPacketView _packet;
  

  HMessage.fromGearthPacket(this.gearthPacket){

    var bytearray = gearthPacket.bytearray;
    
    packetNumberStart = 12;
    // 0x09 = '\t'
    packetNumberEnd = bytearray.indexOf(0x09, 12); 
    // 0x53 = 'S' from "TO'S'ERVER"
    _direction = (bytearray[packetNumberEnd+3] == 0x53) ? Direction.toServer : Direction.toClient; 
    // 0x09 = '\t'
    _isEditedIndex = bytearray.indexOf(0x09, packetNumberEnd+1) + 1; 
    
    _packet = HPacketView.fromBytes(gearthPacket.bytearray, _isEditedIndex + 1); 
  }

  HPacketView get packet => _packet;

  Direction get direction => _direction;

  // 0x31 = '1'
  bool get isBlocked => gearthPacket.bytearray[_isBlockedIndex] == 0x31;

  // 0x31 = '1'
  bool get isEdited => gearthPacket.bytearray[_isEditedIndex] == 0x31;

  set isBlocked(bool value) {
    gearthPacket.bytearray[10] = value ? 0x31 : 0x30;
  }

  set isEdited(bool value){
    gearthPacket.bytearray[_isEditedIndex] = value ? 0x31 : 0x30;
  }

  String get packetNumber => ascii.decode(Uint8List.sublistView(gearthPacket._bytearray, packetNumberStart, packetNumberEnd));
}

class HPacketView{

  int readIndex = 6;
  late final ByteData _bytearray;

  Uint8List get bytearray => Uint8List.sublistView(_bytearray);
  
  HPacketView(this._bytearray);

  HPacketView.fromBytes(TypedData data, [int start = 0, int? end]){
    _bytearray = ByteData.sublistView(data, start, end);
  }

  int headerId()	{
      return _bytearray.getUint16(4);
  }

  void setId(int value)	{
    _bytearray.setUint16(4, value);
  }

  int length()	{
    return readInt(0);
  }

  void replaceShort(int index, int value){
    _bytearray.setInt16(index, value);
  }

  void skipShort(){
    readIndex += 2;
  }
  
  void skipInt(){
    readIndex += 4;
  }
  
  void skipLong(){
    readIndex += 8;
  }

  void skipString(){
    int strSize = _bytearray.getUint16(readIndex);
    readIndex += 2 + strSize;
  }

  void skipLongString(){
    int strSize = _bytearray.getUint32(readIndex);
    readIndex += 2 + strSize;
  }



  bool readBool([int? index]){
    return (readByte(index) == 0) ? false : true;
  }

  int readByte([int? index]){
    if(index == null){
      index = readIndex;
      readIndex += 1;
    }
    return _bytearray.getInt8(index);
  }

  int readShort([int? index]){
    if(index == null){
      index = readIndex;
      readIndex += 2;
    }
    return _bytearray.getInt16(index);
  }

  int readInt([int? index]){
    if(index == null){
      index = readIndex;
      readIndex += 4;
    }
    return _bytearray.getInt32(index);
  }

  int readLong([int? index]){
    if(index == null){
      index = readIndex;
      readIndex += 8;
    }
    return _bytearray.getInt64(index);
  }

  double readFloat([int? index]){
    if(index == null){
      index = readIndex;
      readIndex += 4;
    }
    return _bytearray.getFloat32(index);
  }

  double readDouble([int? index]){
    if(index == null){
      index = readIndex;
      readIndex += 8;
    }
    return _bytearray.getFloat64(index);
  }

  String readString([int? index]){
      index??=readIndex;
      int strSize = _bytearray.getUint16(index);

      if(index == readIndex){
        readIndex += 2 + strSize;
      }
      return utf8.decode(Uint8List.sublistView(_bytearray, index+2, index+2+strSize));
  }

  String readLongString([int? index]){
    index ??= readIndex;
    int strSize = _bytearray.getUint32(index);
    if(index == readIndex){
      readIndex += 4 + strSize;
    }
    return latin1.decode(Uint8List.sublistView(_bytearray, index+4, index+4+strSize));
  }

  Uint8List readBytes(int length, [int? index])	{
    index ??= readIndex;
    return Uint8List.sublistView(_bytearray, index, index+length);
  }
}


class HPacket{

  bool isEdited = false;
  String? idName;
  int readIndex = 6;

  // Uint8List? _bytearray;
  final BytesBuilder bytearrayBuilder = BytesBuilder(copy:false);

  // id must be a int
  Uint8List get bytearray {
    if(idName != null){
      throw const FormatException("For safety HPacket id can't be a String when getting bytearray");
    }

    var value = bytearrayBuilder.toBytes();
    ByteData.sublistView(value, 0, 17).setUint32(11, value.length - 15);
    return Uint8List.sublistView(value, 11);
  }

  Uint8List toMessagePacket(Extension extension, Direction direction){

    var value = bytearrayBuilder.toBytes();

    var bdata = ByteData.sublistView(value, 0, 17);
    
    bdata.setUint32(0, value.length - 4);
    bdata.setUint16(4, OutgoingMessages.sendMessage);
    bdata.setUint8(6, (direction == Direction.toServer )? 1: 0);
    bdata.setUint32(7, value.length - 11);
    bdata.setUint32(11, value.length - 15);
    
    if(idName !=  null){
      bdata.setUint16(15, extension.getHeaderId(direction, idName!));
    }

    return value;
  }
 
  //   4  | 2 |1|  4  |  4  | 2 | buffer
  HPacket(Object id, [List<Object>? args]){

    var byteHeader = ByteData(17);

    if(id is int){
      byteHeader.setUint16(15, id);
    }else if(id is String){
      idName = id;
    }else{
      throw FormatException("Invalid HPacket id type: $id");
    }

    bytearrayBuilder.add(Uint8List.sublistView(byteHeader));

    append(args);

  }

  // int headerId()	{
  //   _bytearray ??= bytearrayBuilder.toBytes();
  //   return ByteData.sublistView(_bytearray!).getUint16(4);
  // }

  // int length()	{
  //   return readInt(0);
  // }

  // int fixSize()	{
  //   return readInt(0);
  // }

  
  
  void append([List<Object>? args]){
    for(Object arg in (args??[]))
    {
      appendObject(arg);
    }
  }

  void appendObject(Object o){
    if (o is int) {
      appendInt(o);
    }
    else if (o is String) {
      appendString(o);
    }
    else if (o is bool) {
      appendBool(o);
    }
    else if (o is Uint8List) {
      appendBytes(o);
    }
    else if (o is double) {
      appendFloat(o);
    }
    else {
        throw const FormatException("Invalid parameter on HPacket");
    }
  }

  void appendBool(bool value){
    bytearrayBuilder.addByte(value ? 1 : 0);
  }

  void appendByte(int value){
    bytearrayBuilder.addByte(value);
  }

  void appendShort(int value){
    var bdata = ByteData(2)..setInt16(0, value);
    bytearrayBuilder.add(Uint8List.sublistView(bdata));
  }

  void appendInt(int value){
    var bdata = ByteData(4)..setInt32(0, value);
    bytearrayBuilder.add(Uint8List.sublistView(bdata));
  }

  void appendLong(int value){
    var bdata = ByteData(8)..setInt64(0, value);
    bytearrayBuilder.add(Uint8List.sublistView(bdata));
  }

  void appendFloat(double value){
    var bdata = ByteData(4)..setFloat32(0, value);
    bytearrayBuilder.add(Uint8List.sublistView(bdata));
  }

  void appendDouble(double value){
    var bdata = ByteData(8)..setFloat64(0, value);
    bytearrayBuilder.add(Uint8List.sublistView(bdata));
  }

  void appendString(String value){
    var strSize = ByteData(2)..setUint16(0, value.length);
    bytearrayBuilder.add(Uint8List.sublistView(strSize) + utf8.encode(value));
  }

  void appendLongString(String value){
    var strSize = ByteData(4)..setUint32(0, value.length);
    bytearrayBuilder.add(Uint8List.sublistView(strSize) + latin1.encode(value));
  }

  void appendBytes(Uint8List value){
    bytearrayBuilder.add(value);
  }

  // int readByte([int? index]){
  //   _bytearray ??= bytearrayBuilder.toBytes();
  //   return _bytearray![index??readIndex];
  // }

  // bool readBool([int? index]){
  //   return (readByte(index) == 0) ? false : true;
  // }

  // int readShort([int? index]){
  //   _bytearray ??= bytearrayBuilder.toBytes();
  //   return ByteData.sublistView(_bytearray!).getInt16(index??readIndex);
  // }

  // int readInt([int? index]){
  //   _bytearray ??= bytearrayBuilder.toBytes();
  //   return ByteData.sublistView(_bytearray!).getInt32(index??readIndex);
  // }

  // int readLong([int? index]){
  //   _bytearray ??= bytearrayBuilder.toBytes();
  //   return ByteData.sublistView(_bytearray!).getInt64(index??readIndex);
  // }

  // double readFloat([int? index]){
  //   _bytearray ??= bytearrayBuilder.toBytes();
  //   return ByteData.sublistView(_bytearray!).getFloat32(index??readIndex);
  // }

  // double readDouble([int? index]){
  //   _bytearray ??= bytearrayBuilder.toBytes();
  //   return ByteData.sublistView(_bytearray!).getFloat64(index??readIndex);
  // }

  // String readString([int? index]){
  //   index ??= readIndex;
  //   _bytearray ??= bytearrayBuilder.toBytes();
  //   int strSize = ByteData.sublistView(_bytearray!).getUint16(index);
  //   return utf8.decode(Uint8List.sublistView(_bytearray!, index+2, index+2+strSize));
  // }

  // String readLongString([int? index]){
  //   index ??= readIndex;
  //   _bytearray ??= bytearrayBuilder.toBytes();
  //   int strSize = ByteData.sublistView(_bytearray!).getUint32(index);
  //   return latin1.decode(Uint8List.sublistView(_bytearray!, index+2, index+2+strSize));
  // }

  // Uint8List readBytes(int length, [int? index])	{
  //   index ??= readIndex;
  //   _bytearray ??= bytearrayBuilder.toBytes();
  //   return Uint8List.sublistView(_bytearray!, index, index+length);
  // }
}