import 'dart:async';
import 'dart:convert';
import 'dart:html';

import 'dart:math';

CanvasElement el;
CanvasRenderingContext2D ctx;

const width = 800;
const height = 600;

class Game {
  int leftPaddle, rightPaddle;
  Point ballPos, ballV;
  int scoreLeft = 0;
  int scoreRight = 0;

  Game(this.leftPaddle, this.rightPaddle, this.ballPos, this.ballV,
      {this.scoreLeft, this.scoreRight});
}

Game game;

const int paddleSize = 140;

WebSocket socket;
bool isHost;

const accell = 1.05;

void main() async {
  socket = WebSocket('ws://${window.location.hostname}:8081');
  socket.onMessage.listen((event) {
    recieveNet(event.data);
  });
  game = Game(300 - paddleSize ~/ 2, 300 - paddleSize ~/ 2, Point(400, 300),
      Point(10, 10),
      scoreLeft: 0, scoreRight: 0);
  reset(true);

  isHost = window.location.hash == '#host';

  el = querySelector('#output');
  ctx = el.getContext('2d');

  window.onMouseMove.listen((MouseEvent event) {
    if (isHost) {
      game.leftPaddle =
          (event.client.y - el.offsetTop) * window.devicePixelRatio -
              paddleSize / 2;
    } else {
      game.rightPaddle =
          (event.client.y - el.offsetTop) * window.devicePixelRatio -
              paddleSize / 2;
    }
  });

  el.width = width;
  el.height = height;
  el.style.width = '${width / window.devicePixelRatio}px';
  el.style.height = '${height / window.devicePixelRatio}px';
  loop(await window.animationFrame);
}

void loop(num time) async {
  await tick(time);
  await render(time);
  loop(await window.animationFrame);
}

void reset(bool winner) {
  game.ballPos = Point(width / 2, height / 2);
  game.ballV = Point(winner ? 10 : -10, 0);
  if (socket.readyState == 1) socket.send(jsonEncode({'type': 'reset'}));
}

Future<void> tick(num time) async {
  // Bounce off top and bottom
  if (isHost) {
    if (game.ballPos.y < 0 || game.ballPos.y > height) {
      game.ballPos = Point(game.ballPos.x, game.ballPos.y.clamp(5, height - 5));
      game.ballV = Point(game.ballV.x, game.ballV.y * -1);
    }

    // Ball sides
    if (game.ballPos.x <= 10 || game.ballPos.x >= width - 10) {
      // Is left pad
      if (game.ballPos.x < width / 2 &&
          game.ballPos.y >= game.leftPaddle - paddleSize / 2 &&
          game.ballPos.y <= game.leftPaddle + paddleSize / 2) {
        game.ballPos = Point(15, game.ballPos.y);
        game.ballV = Point(game.ballV.x.abs() * accell,
            game.ballV.y + (game.ballPos.y - game.leftPaddle) * 0.04);
        sendV();
      } else if (game.ballPos.x > width / 2 &&
          game.ballPos.y >= game.rightPaddle - paddleSize / 2 &&
          game.ballPos.y <= game.rightPaddle + paddleSize / 2) {
        game.ballPos = Point(width - 15, game.ballPos.y);
        game.ballV = Point(-game.ballV.x.abs() * accell,
            game.ballV.y + (game.ballPos.y - game.rightPaddle) * 0.04);
        sendV();
      } else if (game.ballPos.x < width / 2) {
        game.scoreRight++;
        sendScore();
        reset(true);
      } else {
        game.scoreLeft++;
        sendScore();
        reset(false);
      }
    }

    // Move the ball
    game.ballPos += game.ballV;
  }
  if (socket.readyState == 1) {
    if (isHost) {
      socket.send(jsonEncode({
        'type': 'ballPos',
        'data': [game.ballPos.x, game.ballPos.y]
      }));
      sendV();
      socket.send(jsonEncode({'type': 'left', 'data': game.leftPaddle}));
    } else {
      socket.send(jsonEncode({'type': 'right', 'data': game.rightPaddle}));
    }
  }
}

void sendV() {
  socket.send(jsonEncode({
    'type': 'ballPos',
    'data': [game.ballPos.x, game.ballPos.y]
  }));
}

void sendScore() {
  socket.send(jsonEncode({
    'type': 'score',
    'data': [game.scoreLeft, game.scoreRight]
  }));
}

void render(num time) {
  ctx.clearRect(0, 0, width, height);

  //Paddles
  // Left
  ctx.fillRect(0, game.leftPaddle - paddleSize / 2, 20, paddleSize);
  // Right
  ctx.fillRect(width, game.rightPaddle - paddleSize / 2, -20, paddleSize);

  // Ball
  ctx.beginPath();
  ctx.arc(game.ballPos.x, game.ballPos.y, 10, 0, pi * 2);
  ctx.fill();

  // HUD
  ctx.font = '32px monospace';
  ctx.textAlign = 'right';
  ctx.textBaseline = 'top';
  ctx.fillText('${game.scoreLeft}', width / 2 - 20, 10);
  ctx.textAlign = 'left';
  ctx.fillText('${game.scoreRight}', width / 2 + 20, 10);
  ctx.textAlign = 'center';
  ctx.fillText('-', width / 2, 10);
}

void recieveNet(String message) {
  try {
    final d = jsonDecode(message);
    switch (d['type']) {
      case 'ballPos':
        game.ballPos = Point(d['data'][0], d['data'][1]);
        break;
      case 'ballVelocity':
        game.ballV = Point(d['data'][0], d['data'][1]);
        break;
      case 'left':
        game.leftPaddle = d['data'] ~/ 1;
        break;
      case 'right':
        game.rightPaddle = d['data'] ~/ 1;
        break;
      case 'score':
        game.scoreLeft = d['data'][0] ~/ 1;
        game.scoreRight = d['data'][1] ~/ 1;
        break;
      case 'reset':
        reset(d['data']);
    }
  } catch (err) {/* lol */}
}
