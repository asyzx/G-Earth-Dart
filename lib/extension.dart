
import 'dart:io';
import 'dart:typed_data';
import 'hpacket.dart';


enum Event{
  onError,
  onDone,
  onInit,
  onConnectionStart,
  onConnectionEnd,
  onDoubleClick;
}

typedef InterceptFunction = void Function(HMessage);
typedef InterceptFunctionMap = Map<int, InterceptFunction>;

class ExtensionInfo{
  final String title, author, version, description;
  final bool useClickTrigger, canLeave, canDelete;
  ExtensionInfo({this.title="None",  this.author="unknown", this.version="0.0", this.description="", 
    this.useClickTrigger=false, this.canLeave=true, this.canDelete=true});
}

class CallbackManager{

  bool _connectionStarted = false;

  Map<String, int> clientHeaderString = {};
  Map<String, int> serverHeaderString = {};

  List<(Direction, String, InterceptFunction)> interceptFunctions = [];
  InterceptFunctionMap clientIntercepetFunctions = {};
  InterceptFunctionMap serverIntercepetFunctions = {};

  CallbackManager();

  set connectionStarted(bool value) {
    _connectionStarted=value;
    if(value==true){
      for (final element in interceptFunctions){
        _addFunction(element.$1, element.$2, element.$3);
      }
    }else{
      clientHeaderString.clear();
      serverHeaderString.clear();
      clientIntercepetFunctions.clear();
      serverIntercepetFunctions.clear();
    }
  }

  int getHeaderId(Direction dir, String idName){
    late int? id;
    if(dir == Direction.toServer){
      id = clientHeaderString[idName];
    }
    else{
      id = serverHeaderString[idName];
    }
    if(id == null){
      throw FormatException("Invalid id name: $idName");
    }
    return id;
  }


  void intercept(Direction direction, String id, InterceptFunction func) async {
    interceptFunctions.add((direction, id, func));
    if(_connectionStarted){
      _addFunction(direction, id, func);
    }
  }

  void removeIntercept(Direction direction, String id){
    interceptFunctions.removeWhere( (element) => element.$1 == direction && element.$2 == id);
    if(_connectionStarted){
      _removeFunction(direction, id);
    }
  }

  void _addFunction(Direction direction, String id, InterceptFunction func){
    if(direction == Direction.toServer)
    {
      int shortId = getHeaderId(Direction.toServer, id);
      clientIntercepetFunctions[shortId] = func;
    }
    else
    {
      int shortId = getHeaderId(Direction.toClient, id);
      serverIntercepetFunctions[shortId] = func;
    }
  }


  void _removeFunction(Direction direction, String id) async {
    if(direction == Direction.toServer)
    {
      int shortId = getHeaderId(Direction.toServer, id);
      clientIntercepetFunctions.remove(shortId);
    }
    else
    {
      int shortId = getHeaderId(Direction.toClient, id);
      serverIntercepetFunctions.remove(shortId);
    }
  }

  void callFunction(HMessage msg){
    var packetId = msg.packet.headerId();
    if(msg.direction != Direction.toServer){
      var func = serverIntercepetFunctions[packetId];
      if (func != null){
        func(msg);
      }
    }
    else{
      var func = clientIntercepetFunctions[packetId];
      if (func != null){
        func(msg);
      }
    }
  }
}



class Extension extends CallbackManager{

  late Socket socket;

  /* Variables that neeed to await connectionStarted */
  late String clientHost;
  late int clientPort;
  late String hotelVersion;
  late String clientIdentifier;
  late String clientType;
  /* ----------------------------------------------- */

  final ExtensionInfo _extensionInfo;
  String fileString, cookieString;

  void Function([Error?])? onError;

  // double_click, connection_start, connection_end, init
  void Function()? onDone, onDoubleClick, onConnectionStart, onConnectionEnd, onInit;

  Extension(this._extensionInfo, [this.fileString="", this.cookieString="", this.onError, this.onDone]): super();

  void stop(){
    socket.close();
  }

  void start([String host='127.0.0.1', int port=9092]) async {
    socket = await Socket.connect(host, port);
    // socket.setOption(SocketOption.tcpNoDelay, true);

    socket.listen( 
      recvGearthPacket, 
      // onDone: onDone,
      // onError: onError,
    );

    await socket.done;
  }

  int waitingSize = 0;
  BytesBuilder dataWaiting =  BytesBuilder();

  void recvGearthPacket(Uint8List buffer){
    try {
      _processData(buffer);
    } on Error catch(e) {
      if(onError != null) {
        onError!(e);
      } else {
        rethrow;
      }
    } 
  }

  void _processData(Uint8List buffer){
    int bufferReadIndex = 0;
    if(dataWaiting.isNotEmpty){ // tem bytes anteriores?

        if(dataWaiting.length < 4) // waitingSize incomplete
        {
          print('waitingSize imcomplete');

          if(dataWaiting.length + buffer.length < 4){
            dataWaiting.add(buffer);
            return;
          }

          bufferReadIndex = 4 - dataWaiting.length;
          dataWaiting.add(Uint8List.sublistView(buffer, 0, bufferReadIndex));
          waitingSize = ByteData.sublistView(dataWaiting.toBytes()).getUint32(0);
        } 

        if(waitingSize <= buffer.length - bufferReadIndex) 
        {
          print('Waiting Packet complete');
          dataWaiting.add(Uint8List.sublistView(buffer, bufferReadIndex, waitingSize));
          processGEarthPacket(HPacketView.fromBytes(dataWaiting.takeBytes()));
          bufferReadIndex += waitingSize;
          waitingSize = 0;
        } 
        else // message is incomplete
        {
          print('Packet imcomplete');
          waitingSize -= buffer.length - bufferReadIndex;
          dataWaiting.add(Uint8List.sublistView(buffer, bufferReadIndex));
        }
      }

      int remainingBytes = buffer.length - bufferReadIndex;

      while(remainingBytes >= 4) // para se nao tem mais nada no buffer 
      {
        int messageSize = ByteData.sublistView(buffer, bufferReadIndex).getUint32(0);
        if(remainingBytes >= 4 + messageSize)
        {
          processGEarthPacket(HPacketView.fromBytes(buffer, bufferReadIndex, bufferReadIndex + 4 + messageSize));
          bufferReadIndex += 4 + messageSize;
        }
        else // too small for messageSize
        {
          dataWaiting.add(Uint8List.sublistView(buffer, bufferReadIndex));
          waitingSize = 4 + messageSize - remainingBytes;
          return;
        } 
        remainingBytes = buffer.length - bufferReadIndex;
      }

      if(remainingBytes > 0){
        dataWaiting.add(Uint8List.sublistView(buffer, bufferReadIndex));
      }

  }

  void sendGearthPacket(HPacket gearthPacket){
      socket.add(gearthPacket.bytearray);
  }

  void sendGearthPacketView(HPacketView gearthPacket){
      socket.add(gearthPacket.bytearray);
  }


  void __parsePacketInfos(HPacketView gearthPacket){

    clientHost = gearthPacket.readString();
    clientPort = gearthPacket.readInt();
    hotelVersion = gearthPacket.readString();
    clientIdentifier = gearthPacket.readString();
    clientType = gearthPacket.readString();

    for(var fieldsSize = gearthPacket.readInt(); fieldsSize != 0; fieldsSize--)
    {
      var headerId = gearthPacket.readInt();
      gearthPacket.skipString();
      var headerName = gearthPacket.readString();
      gearthPacket.skipString();
      var isOutgoing = gearthPacket.readBool();
      gearthPacket.skipString();

      if(isOutgoing){
        clientHeaderString[headerName] = headerId;
      }else{
        serverHeaderString[headerName] = headerId;
      }
    }
  }


  

  void processGEarthPacket(HPacketView gearthPacket){
    var gearthID = gearthPacket.headerId();
    switch (gearthID)
    {
        case IncomingMessages.infoRequest:
            sendExtensionInfo();
            
        case IncomingMessages.connectionStart:
            __parsePacketInfos(gearthPacket);
            connectionStarted = true;
            onConnectionStart?.call();
            
        case IncomingMessages.connectionEnd:
            connectionStarted = false;
            onConnectionEnd?.call();
            
        case IncomingMessages.flagsCheck:
            print("FLAGSCHECK\n");
            
        case IncomingMessages.init:
            onInit?.call();
            
        case IncomingMessages.onDoubleClick:
            onDoubleClick?.call();
            
        case IncomingMessages.packetIntercept:
            verifyPacket(gearthPacket);
            
        case IncomingMessages.packetToStringResponse:
            print("PACKETTOSTRINGRESPONSE\n");
            
        case IncomingMessages.stringToPacketResponse:
            print("STRINGTOPACKETRESPONSE\n");
            
        default:
            print("Invalid G-Earth Packet!");
    }
  }

  void _sendMessage(Direction direction, HPacket packet){
    socket.add(packet.toMessagePacket(this, direction));
  }

  void sendToClient(HPacket packet) {
    _sendMessage(Direction.toClient, packet);
  }

  void sendToServer(HPacket packet) {
    _sendMessage(Direction.toServer, packet);
  }


  // double_click, connection_start, connection_end, init
  void onEvent(String eventName, void Function() func){
    switch(eventName){
      case "double_click":
        onDoubleClick = func;
      case "connection_start":
        onConnectionStart = func;
      case "connection_end":
        onConnectionEnd = func;
      case "init":
        onInit = func;
      default:
        throw FormatException("Invalid event name: $eventName");
    }
  }

  void verifyPacket(HPacketView gearthPacket){

    var msg = HMessage.fromGearthPacket(gearthPacket);

    callFunction(msg);
    
    gearthPacket.setId(OutgoingMessages.manipulatedPacket);
    sendGearthPacketView(gearthPacket);
  }

  void sendExtensionInfo(){
    var outputPacket = 
      HPacket(
        OutgoingMessages.extensionInfo,
        [
          _extensionInfo.title,		 // title
          _extensionInfo.author,		 // author
          _extensionInfo.version,		 // version
          _extensionInfo.description,		 // description
          _extensionInfo.useClickTrigger, // useClickTrigger
          fileString.isEmpty ? false: true, // file?
          fileString,		 // file string
          cookieString,		 // cookie string
          _extensionInfo.canLeave, // canLeave
          _extensionInfo.canDelete	 // canDelete
        ]
      );
    sendGearthPacket(outputPacket);
  }

}