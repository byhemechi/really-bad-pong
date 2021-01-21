import 'dart:io';

main() async {
  final server = await HttpServer.bind(InternetAddress.anyIPv6, 8081);
  print('Listening on ${server.port}');

  final List<WebSocket> sockets = [];

  server.listen((req) async {
    if (WebSocketTransformer.isUpgradeRequest(req)) {
      final socket = await WebSocketTransformer.upgrade(req);
      sockets.add(socket);
      await for (var msg in socket) {
        sockets.forEach((element) {
          // stdout.write('\r${msg}');
          if (element != socket) element.add(msg);
        });
      }
    } else {
      req.response.write('lol no');
      req.response.close();
    }
  });
}
