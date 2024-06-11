

import 'dart:typed_data';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'package:gearth/extension.dart';
import 'package:gearth/hpacket.dart';

class MockExtension extends Mock implements Extension{
  @override Map<String, int> clientHeaderString = {
    "MoveAvatar": 2947,
  };

  @override Map<String, int> serverHeaderString = {
    "MoveAvatar": 2947,
  };

  @override int getHeaderId(Direction dir, String idName) {

    int? id;
    if(dir == Direction.toServer){
      id = clientHeaderString[idName];
    }
    else if(dir == Direction.toClient){
      id = serverHeaderString[idName];
    }

    if(id != null){
      return id;
    }

    throw FormatException("GetId: Invalid id name: $idName");
  }
}


void main() {

  group("HPacket -", () {
      var packet1 = HPacket(2947, [7, 4]);
      var packet2 = HPacket("MoveAvatar", [7, 4]);

    test("get bytearray", () {
      var result = Uint8List.fromList([0, 0, 0, 10, 11, 131, 0, 0, 0, 7, 0, 0, 0, 4]);
      expect(result, packet1.bytearray);

      try{
        var bytes = packet2.bytearray;
        expect(result, bytes);
      } on FormatException catch(e) {
        expect("For safety HPacket id can't be a String when getting bytearray", e.message);
      }
    });
    test("toMessagePacket", () {

      var ext = MockExtension();

      var resultToServer = Uint8List.fromList([0, 0, 0, 21, 0, 4, 1, 0, 0, 0, 14, 0, 0, 0, 10, 11, 131, 0, 0, 0, 7, 0, 0, 0, 4]);
      var resultToClient = Uint8List.fromList([0, 0, 0, 21, 0, 4, 0, 0, 0, 0, 14, 0, 0, 0, 10, 11, 131, 0, 0, 0, 7, 0, 0, 0, 4]);
      
      expect(resultToServer, packet1.toMessagePacket(ext, Direction.toServer), reason:"Direction must be to server");
      expect(resultToClient, packet2.toMessagePacket(ext, Direction.toClient), reason:"Direction must be to client");
    
      });
  });

  group("HPacketView -", () {
    var packet1 = HPacketView.fromBytes(Uint8List.fromList([0, 0, 0, 62, 15, 160, 1, 127, 127, 127, 0, 0, 127, 127, 0, 0, 0, 0, 0, 0, 127, 127, 65, 4, 0, 0, 64, 32, 64, 0, 0, 0, 0, 0, 0, 11, 72, 101, 108, 108, 111, 32, 87, 111, 114, 108, 100, 0, 0, 0, 11, 72, 101, 108, 108, 111, 32, 87, 111, 114, 108, 100, 1, 2, 3, 4]));
    
    test("headerId", () {
      expect(packet1.headerId(), 4000);
    });

    test("setId", () {
      packet1.setId(2000);
      expect(packet1.headerId(), 2000);
    });

    test("length", () {
      expect(packet1.length(), 62);
    });

    test("readBool", () {
      expect(packet1.readBool(), true);
    });

    test("readByte", () {
      expect(packet1.readByte(), 0x7f);
    });

    test("readShort", () {
      expect(packet1.readShort(), 0x7f7f);
    });

    test("readInt", () {
      expect(packet1.readInt(), 0x7f7f);
    });

    test("readLong", () {
      expect(packet1.readLong(), 0x7f7f);
    });

    test("readFloat", () {
      expect(packet1.readFloat(), 8.25);
    });

    test("readDouble", () {
      expect(packet1.readDouble(), 8.125);
    });

    test("readString", () {
      expect(packet1.readString(), "Hello World");
    });

    test("readLongString", () {
      expect(packet1.readLongString(), "Hello World");
    });

    test("readBytes", () {
      expect(Uint8List.fromList([1, 2, 3, 4]), packet1.readBytes(4));
    });
    
  });

  group("HMessage -", () {

    var testArray = Uint8List.fromList([0, 0, 0, 31, 0, 3, 0, 0, 0, 25, 48, 9, 53, 57, 9, 84, 79, 67, 76, 73, 69, 78, 84, 9, 48, 0, 0, 0, 6, 12, 31, 0, 0, 0, 0]);
    var msg = HMessage.fromGearthPacket(HPacketView.fromBytes(testArray));
      
    test("fromGearthPacket", () {
      var result = HPacketView.fromBytes(Uint8List.fromList([0, 0, 0, 6, 12, 31, 0, 0, 0, 0]));
      expect(msg.packet.bytearray, result.bytearray);
      expect(msg.direction, Direction.toClient);
      expect(msg.packetNumber, "59");
      expect(msg.isBlocked, false);
      expect(msg.isEdited, false);
    });

    test("get packet", () {
      var result = HPacketView.fromBytes(Uint8List.fromList([0, 0, 0, 6, 12, 31, 0, 0, 0, 0]));
      expect(msg.packet.bytearray, result.bytearray);
    });

    test("get direction", () {
      expect(msg.direction, Direction.toClient);
    });

    test("get packetNumber", () {
      expect(msg.packetNumber, "59");
    });

    test("set/get isBlocked", () {
      
      expect(msg.isBlocked, false);

      msg.isBlocked = true;
      expect(msg.isBlocked, true);
    });

    test("set/get isEdited", () {
      expect(msg.isEdited, false);

      msg.isEdited = true;
      expect(msg.isEdited, true);
    });
  });
}