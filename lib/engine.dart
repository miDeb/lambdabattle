import 'dart:math';
import 'package:flutter/material.dart';

class Delta {
  final int dx;
  final int dy;

  const Delta(this.dx, this.dy);

  @override
  String toString() => '<Δ$dx, Δ$dy>';

  double get magnitude => sqrt(dx * dx + dy * dy);

  @override
  bool operator ==(other) {
    if (other is! Delta) {
      return false;
    }
    return dx == other.dx && dy == other.dy;
  }

  @override
  int get hashCode {
    return hashValues(dx, dy);
  }
}

class Position {
  final int x;
  final int y;

  const Position(this.x, this.y);

  factory Position.random() {
    var rng = Random();
    return Position(rng.nextInt(Board.kWidth), rng.nextInt(Board.kHeight));
  }

  Position apply(Delta delta) => Position(x + delta.dx, y + delta.dy);
  Move move(Delta delta) => Move(this, apply(delta));

  Delta deltaTo(Position other) {
    return Delta(other.x - x, other.y - y);
  }

  @override
  String toString() => '($x, $y)';

  @override
  bool operator ==(other) {
    if (other is! Position) {
      return false;
    }
    return x == other.x && y == other.y;
  }

  @override
  int get hashCode {
    return hashValues(x, y);
  }
}

class Move {
  final Position initialPosition;
  final Position finalPosition;

  const Move(this.initialPosition, this.finalPosition);

  @override
  String toString() => '[$initialPosition -> $finalPosition]';

  @override
  bool operator ==(other) {
    if (other is! Move) {
      return false;
    }
    return initialPosition == other.initialPosition &&
        finalPosition == other.finalPosition;
  }

  Delta get delta => initialPosition.deltaTo(finalPosition);

  @override
  int get hashCode {
    return hashValues(initialPosition, finalPosition);
  }
}

abstract class Player {
  String get name;
  Color get color;

  const Player();

  void paint(Canvas canvas, Rect rect, PieceType type) {
    var paint = Paint();
    paint.style = PaintingStyle.fill;
    paint.color = color;
    switch (type) {
      case PieceType.king:
        canvas.drawOval(rect, paint);
    }
  }

  @override
  String toString() => 'Player[$name]';
}

enum PieceType {
  king,
}

class Piece {
  final PieceType type;
  final Player owner;

  const Piece(this.type, this.owner);

  Iterable<Delta> get deltas sync* {
    switch (type) {
      case PieceType.king:
        for (int dx = -1; dx <= 1; ++dx) {
          for (int dy = -1; dy <= 1; ++dy) {
            if (dx == 0 && dy == 0) {
              continue;
            }
            yield Delta(dx, dy);
          }
        }
        break;
    }
  }
}

class IllegalMove {
  final String reason;
  const IllegalMove(this.reason);
}

class Board {
  static const int kWidth = 8;
  static const int kHeight = 8;

  static bool inBounds(Position position) {
    return position.x >= 0 &&
        position.x < kWidth &&
        position.y >= 0 &&
        position.y < kHeight;
  }

  final Map<Position, Piece> _pieces;

  Board.empty() : _pieces = <Position, Piece>{};
  Board._(this._pieces);

  void forEachPiece(void Function(Position position, Piece piece) callback) {
    _pieces.forEach(callback);
  }

  Board placeAt(Position postion, Piece piece) {
    return Board._(<Position, Piece>{postion: piece, ..._pieces});
  }

  Piece? getAt(Position position) {
    return _pieces[position];
  }

  Board move(Player player, Move move) {
    var piece = getAt(move.initialPosition);
    if (piece == null) {
      throw IllegalMove('No piece at ${move.initialPosition}.');
    }
    if (piece.owner != player) {
      throw IllegalMove(
          'Piece at ${move.initialPosition} not owned by $player.');
    }
    if (!inBounds(move.finalPosition)) {
      throw IllegalMove(
          'Final position ${move.finalPosition} is out-of-bounds.');
    }
    if (piece.owner == getAt(move.finalPosition)?.owner) {
      throw IllegalMove(
          'Pieces at ${move.initialPosition} and ${move.finalPosition} have the same owner.');
    }
    var newPieces = <Position, Piece>{..._pieces};
    newPieces.remove(move.initialPosition);
    newPieces[move.finalPosition] = piece;
    return Board._(newPieces);
  }

  bool isLegalMove(Player player, Move move) {
    var piece = getAt(move.initialPosition);
    return piece != null &&
        piece.owner == player &&
        _canMovePieceTo(piece, move.finalPosition);
  }

  bool _canMovePieceTo(Piece piece, Position position) {
    return inBounds(position) && piece.owner != getAt(position)?.owner;
  }

  Iterable<Move> getLegalMoves(Player player) sync* {
    for (var position in _pieces.keys) {
      var piece = getAt(position);
      if (piece == null || piece.owner != player) {
        continue;
      }
      for (var delta in piece.deltas) {
        var move = position.move(delta);
        if (_canMovePieceTo(piece, move.finalPosition)) {
          assert(isLegalMove(player, move));
          yield move;
        }
      }
    }
  }

  bool hasPieceOfType(Player player, PieceType type) {
    for (var piece in _pieces.values) {
      if (piece.owner == player && piece.type == type) {
        return true;
      }
    }
    return false;
  }

  bool isAlive(Player player) => hasPieceOfType(player, PieceType.king);
}

class GameState {
  final Board board;
  // In move order.
  final List<Player> players;
  // In death order.
  final List<Player> deadPlayers;
  static const int turnsUntilDrawDefault = 50;
  final int turnsUntilDraw;

  Player get activePlayer => players.first;

  GameState(this.board, this.players, this.deadPlayers,
      [this.turnsUntilDraw = turnsUntilDrawDefault]);

  GameState.empty() : this(Board.empty(), const <Player>[], const <Player>[]);

  GameState move(Move move) {
    var newBoard = board.move(activePlayer, move);
    var newPlayers = <Player>[];
    var newDeadPlayers = List<Player>.from(deadPlayers);
    for (var i = 1; i < players.length; ++i) {
      var player = players[i];
      if (newBoard.isAlive(player)) {
        newPlayers.add(player);
      } else {
        newDeadPlayers.add(player);
      }
    }
    newPlayers.add(activePlayer);
    var newTurnsUntilDraw = turnsUntilDraw - 1;
    var playerDied = players.length != newPlayers.length;
    if (playerDied) {
      newTurnsUntilDraw = turnsUntilDrawDefault;
    }
    return GameState(newBoard, newPlayers, newDeadPlayers, newTurnsUntilDraw);
  }

  bool get isDraw => turnsUntilDraw <= 0;

  Player? get winner {
    if (players.length != 1) {
      return null;
    }
    return activePlayer;
  }

  bool get isDone => isDraw || winner != null;
}

class AgentView {
  final GameState _gameState;
  final Player _player;

  AgentView(this._gameState, this._player);

  Iterable<Position> getPositions(PieceType type) {
    List<Position> positions = <Position>[];
    _gameState.board.forEachPiece((position, piece) {
      if (piece.owner == _player && piece.type == type) {
        positions.add(position);
      }
    });
    return positions;
  }

  Position? closestOpponent(Position position, PieceType type) {
    Position? bestPosition;
    double bestDistance = double.infinity;
    _gameState.board.forEachPiece((currentPosition, piece) {
      if (piece.owner == _player || piece.type != type) {
        return;
      }
      var currentDistance = position.deltaTo(currentPosition).magnitude;
      if (currentDistance < bestDistance) {
        bestDistance = currentDistance;
        bestPosition = currentPosition;
      }
    });
    return bestPosition;
  }

  Iterable<Move> get legalMoves => _gameState.board.getLegalMoves(_player);
}

const double kValue = 16.0;
const double initialRating = 500.0;

class GameHistory {
  final Map<String, double> wins = <String, double>{};
  int gameCount = 0;

  final Map<String, double> rating = <String, double>{};

  double expectedScore(double currentRating, double opponentRating) {
    var exponent = (opponentRating - currentRating) / 400.0;
    return 1.0 / (1.0 + pow(10.0, exponent));
  }

  double pointsToTransfer(double score, double expectedScore) {
    return kValue * (score - expectedScore);
  }

  double currentRatingForName(String name) {
    return rating[name] ?? initialRating;
  }

  double currentRating(Player player) => currentRatingForName(player.name);

  void adjustRating(Player player, double delta) {
    rating[player.name] = currentRating(player) + delta;
  }

  void updateRating(Player winner, Player loser, double score) {
    var winnerRating = currentRating(winner);
    var loserRating = currentRating(loser);
    var stake =
        pointsToTransfer(score, expectedScore(winnerRating, loserRating));
    adjustRating(winner, stake);
    adjustRating(loser, -stake);
  }

  void recordGame(GameState gameState) {
    var pointsPerPlayer = 1.0 / gameState.players.length;
    for (var player in gameState.players) {
      var name = player.name;
      wins[name] = (wins[name] ?? 0.0) + pointsPerPlayer;
      gameCount += 1;
    }
    // http://www.tckerrigan.com/Misc/Multiplayer_Elo/
    // record dead players as losing against the next dead.
    for (var i = 0; i < gameState.deadPlayers.length - 1; i++) {
      var winner = gameState.deadPlayers[i + 1];
      var loser = gameState.deadPlayers[i];
      updateRating(winner, loser, 1.0); // win
    }
    var alivePlayers = List.from(gameState.players);
    alivePlayers.shuffle();
    // record last dead player as losing against random alive player?
    if (gameState.deadPlayers.isNotEmpty) {
      updateRating(alivePlayers.first, gameState.deadPlayers.last, 1.0); // win
    }
    // record alive players in a cycle of draws.
    for (var i = 0; i < alivePlayers.length; i++) {
      for (var j = i + 1; j < alivePlayers.length; j++) {
        updateRating(alivePlayers[i], alivePlayers[j], 0.5); // draw
      }
    }
  }
}

abstract class Agent extends Player {
  const Agent();

  Move pickMove(AgentView view);
}
