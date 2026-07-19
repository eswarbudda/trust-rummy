package com.trustrummy.backend.game.engine;

import com.trustrummy.backend.game.model.GameType;
import com.trustrummy.backend.game.ws.GameActionMessage;
import com.trustrummy.backend.game.ws.GameEvent;

/**
 * The surface a concrete game (Rummy today; Andar Bahar / Teen Patti later)
 * must expose to the transport layer ({@code GameWebSocketHandler}) and the
 * lobby/lifecycle layer ({@code RoomLifecycleService}). Neither of those
 * classes should know about a specific game's internals — they resolve the
 * right implementation for a room via {@code GameEngineRegistry}.
 */
public interface GameEngine {

    /** Which {@link GameType} this engine implements, used as the registry key. */
    GameType supportedGameType();

    /** Routes an inbound WebSocket action for the acting player to this engine. */
    void handleAction(String roomCode, Long userId, GameActionMessage action);

    /** Builds a personalized snapshot for a freshly connected session (e.g. on WebSocket handshake). */
    GameEvent buildSnapshotEventFor(String roomCode, Long userId);

    /** Forces a seated player out of the current round because their WebSocket has been gone too long. */
    void forfeitDisconnectedPlayer(String roomCode, Long userId);
}
