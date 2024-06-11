import 'dart:io';
import 'dart:typed_data';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'package:gearth/extension.dart';
import 'package:gearth/hpacket.dart';

import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class MockSocket extends Mock implements Socket{

  BytesBuilder builder = BytesBuilder(copy:false);  

  @override
  void add(List<int> data) {
    builder.add(data);
  }

  Uint8List readBytes(){
    return builder.takeBytes();
  }
}

void main() async {


  sqfliteFfiInit();

  var databaseFactory = databaseFactoryFfi;

  var dbPath = p.absolute("test_resources", "saved_packets.db");
  var db = await databaseFactory.openDatabase(dbPath);
  

  var mockSocket = MockSocket(); 

  var extInfo = ExtensionInfo(title:"Test Extension", author:"", version:"0.1", description:"Testing");
  var ext = Extension(extInfo);

  ext.socket = mockSocket;

  var packetTest= Map<String, Uint8List>.fromIterable(
    await db.query('PacketTest'),
    key: (item) => item["name"]!,
    value: (item) => item["data"]!,
  );

  group("Extension -", () { 

    ext.recvGearthPacket(packetTest["ConnectionStart"]!);

    test('ConnectionStart', () async {
      expect("game-br.habbo.com", ext.clientHost);
      expect(30000, ext.clientPort);
      expect("WIN63-202405071516-774890658", ext.hotelVersion);
      expect("FLASH19", ext.clientIdentifier);
      expect("FLASH", ext.clientType);


      expect(ext.clientHeaderString.length, 478);
      expect(ext.serverHeaderString.length, 490);
    });

    test('InfoRequest', () {

      ext.recvGearthPacket(packetTest["InfoRequest"]!);

      var result = 
        HPacket(
          OutgoingMessages.extensionInfo,
          [
            extInfo.title,		 // title
            extInfo.author,		 // author
            extInfo.version,		 // version
            extInfo.description,		 // description
            extInfo.useClickTrigger, // useClickTrigger
            ext.fileString.isEmpty ? false: true, // file?
            ext.fileString,		 // file string
            ext.cookieString,		 // cookie string
            extInfo.canLeave, // canLeave
            extInfo.canDelete	 // canDelete
          ]
        ).bytearray; 

      expect(mockSocket.readBytes(), result);
    });


    

    test('onEvent', () async {

      bool result1 = false;
      bool result2 = false;
      bool result3 = false;
      bool result4 = false;

      ext.onEvent("init", () => result1=true );
      ext.onEvent("connection_start", () => result2=true );
      ext.onEvent("connection_end", () => result3=true );
      ext.onEvent("double_click", () => result4=true );

      ext.recvGearthPacket(packetTest["Init"]!);
      ext.recvGearthPacket(packetTest["ConnectionEnd"]!);
      ext.recvGearthPacket(packetTest["ConnectionStart"]!);
      ext.recvGearthPacket(packetTest["onDoubleClick"]!);

      expect(true, result1, reason:"event function init not called");
      expect(true, result2, reason:"event function connection_start not called");
      expect(true, result3, reason:"event function connection_end not called");
      expect(true, result4, reason:"event function double_click not called");
    });
    


    test('intercept', () async {

      bool result1 = false;
      bool result2 = false;

      ext.intercept(Direction.toClient, "AuthenticationOK", (msg) {result1 = true;});
      ext.intercept(Direction.toServer, "ClientHello", (msg) {result2 = true;});

      ext.recvGearthPacket(packetTest["ClientHello"]!);
      ext.recvGearthPacket(packetTest["AuthenticationOK"]!);

      expect(result1, true, reason:"Intercept function to client was not called");
      expect(result2, true, reason:"Intercept function to server was not called");
    });

    group("recvGearthPacket -", () {
      test('incomplete packet', () {

      Uint8List packet = packetTest["InitDiffieHandshake"]!;

      var result = false;
      ext.intercept(Direction.toClient, "InitDiffieHandshake", (msg) {result = true;});
      
      // recving less than 4 bytes and the rest after

      Uint8List packet1_part1 = Uint8List.sublistView(packet, 0, 1);
      Uint8List packet1_part2 = Uint8List.sublistView(packet, 1);

      ext.recvGearthPacket(packet1_part1);
      expect(ext.waitingSize, 0);
      expect(ext.dataWaiting.length, 1);
      ext.recvGearthPacket(packet1_part2);

      expect(result, true, reason:"recving less than 4 bytes and the rest after");
      result = false;

      // test recving 4 bytes and the rest after

      Uint8List packet2_part1 = Uint8List.sublistView(packet, 0, 4);
      Uint8List packet2_part2 = Uint8List.sublistView(packet, 4);

      ext.recvGearthPacket(packet2_part1);
      expect(ext.waitingSize, packet2_part2.length);
      expect(ext.dataWaiting.length, packet2_part1.length);
      ext.recvGearthPacket(packet2_part2);

      expect(result, true, reason:"recving 4 bytes and the rest after");
      result = false;

      // test recving one part and the rest after

      Uint8List packet3_part1 = Uint8List.sublistView(packet, 0, 128);
      Uint8List packet3_part2 = Uint8List.sublistView(packet, 128);

      ext.recvGearthPacket(packet3_part1);
      expect(ext.waitingSize, packet3_part2.length);
      expect(ext.dataWaiting.length, packet3_part1.length);
      ext.recvGearthPacket(packet3_part2);

      expect(result, true, reason:"recving part and the rest after");
      result = false;

    });

    test('multiple packets', () {

      var byteBuilder = BytesBuilder(copy:false);
      byteBuilder.add(packetTest["InitDiffieHandshake"]!);
      byteBuilder.add(packetTest["InitDiffieHandshake"]!);
      byteBuilder.add(packetTest["InitDiffieHandshake"]!);

      Uint8List packet = byteBuilder.toBytes();

      var result = 0;
      ext.intercept(Direction.toClient, "InitDiffieHandshake", (msg) {result+=1;});

      ext.recvGearthPacket(packet);

      expect(result, 3, reason:"recving 3 packets");
      result = 0;

      // recving first byte and rest of packet + 2 complete packets

      Uint8List packet1 = byteBuilder.toBytes();
      Uint8List packet1_part1 = Uint8List.sublistView(packet1, 0, 1);
      Uint8List packet1_part2 = Uint8List.sublistView(packet1, 1);

      ext.recvGearthPacket(packet1_part1);
      expect(ext.waitingSize, 0);
      expect(ext.dataWaiting.length, 1);
      ext.recvGearthPacket(packet1_part2);
      expect(ext.waitingSize, 0);
      expect(ext.dataWaiting.length, 0);

      expect(result, 3, reason:"recving first byte and rest of packet + 2 complete packets");
      result = 0;

      // test recving 4 bytes and the rest after

      Uint8List packet2 = byteBuilder.toBytes();
      Uint8List packet2_part1 = Uint8List.sublistView(packet2, 0, 4);
      Uint8List packet2_part2 = Uint8List.sublistView(packet2, 4);

      ext.recvGearthPacket(packet2_part1);
      ext.recvGearthPacket(packet2_part2);
      expect(ext.waitingSize, 0);
      expect(ext.dataWaiting.length, 0);

      expect(result, 3, reason:"recving less than 4 bytes and the rest after");
      result = 0;

      // test recving one part and the rest after

      Uint8List packet3 = byteBuilder.toBytes();
      Uint8List packet3_part1 = Uint8List.sublistView(packet3, 0, 128);
      Uint8List packet3_part2 = Uint8List.sublistView(packet3, 128);

      ext.recvGearthPacket(packet3_part1);
      ext.recvGearthPacket(packet3_part2);
      expect(ext.waitingSize, 0);
      expect(ext.dataWaiting.length, 0);
      expect(result, 3, reason:"recving part and the rest after");
      result = 0;

    });

  });
    


  });
  

  await db.close();
}