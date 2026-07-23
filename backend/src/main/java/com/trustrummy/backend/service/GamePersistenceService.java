package com.trustrummy.backend.service;

import com.trustrummy.backend.entity.GameMoveLog;
import com.trustrummy.backend.entity.GameSession;
import com.trustrummy.backend.entity.MoveType;
import com.trustrummy.backend.entity.RoomStatus;
import com.trustrummy.backend.entity.SessionStatus;
import com.trustrummy.backend.recentplayers.RecentPlayersPort;
import com.trustrummy.backend.repository.GameMoveLogRepository;
import com.trustrummy.backend.repository.GameRoomRepository;
import com.trustrummy.backend.repository.GameSessionRepository;
import com.trustrummy.backend.repository.RoomPlayerRepository;
import com.trustrummy.backend.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.Map;

/**
 * Durable, audit-trail persistence for the Rummy engine. Every method here
 * is {@code @Async} — {@code RummyEngineService} fires-and-forgets these
 * calls so the WebSocket hot path (draw/discard/declare/drop) never blocks
 * on a database round-trip. They all run on the single-threaded
 * {@code gamePersistenceExecutor} (see {@code AsyncConfig}) rather than
 * Spring's shared default pool, so that {@code recordMatchStart} for a room
 * is always fully applied before that same room's {@code recordMatchEnd}
 * runs, even though both are asynchronous from the caller's point of view.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class GamePersistenceService {

    private final GameRoomRepository gameRoomRepository;
    private final GameSessionRepository gameSessionRepository;
    private final GameMoveLogRepository gameMoveLogRepository;
    private final RoomPlayerRepository roomPlayerRepository;
    private final UserRepository userRepository;
    private final RecentPlayersPort recentPlayersPort;

    @Async("gamePersistenceExecutor")
    @Transactional
    public void recordMatchStart(String roomCode) {
        gameRoomRepository.findByRoomCode(roomCode).ifPresentOrElse(room -> {
            room.setStatus(RoomStatus.IN_PROGRESS);
            gameRoomRepository.save(room);

            GameSession session = GameSession.builder()
                    .gameRoom(room)
                    .status(SessionStatus.ACTIVE)
                    .build();
            gameSessionRepository.save(session);
        }, () -> log.warn("recordMatchStart: unknown room {}", roomCode));
    }

    @Async("gamePersistenceExecutor")
    @Transactional
    public void recordMove(String roomCode, Long userId, MoveType moveType, String moveDataJson, long sequenceNo) {
        gameRoomRepository.findByRoomCode(roomCode).ifPresent(room ->
                gameSessionRepository.findFirstByGameRoomIdOrderByStartedAtDesc(room.getId()).ifPresent(session ->
                        userRepository.findById(userId).ifPresent(user -> {
                            GameMoveLog moveLog = GameMoveLog.builder()
                                    .gameSession(session)
                                    .user(user)
                                    .moveType(moveType)
                                    .moveData(moveDataJson)
                                    .sequenceNo(sequenceNo)
                                    .build();
                            gameMoveLogRepository.save(moveLog);
                        })));
    }

    /**
     * Flushes the outcome of a finished match to the database.
     * <p>
     * A match with no {@code winnerUserId} (e.g. every remaining player
     * dropped/forfeited out of the same deal simultaneously, or the last
     * active seat disconnected before anyone could be declared a winner)
     * never reached a real gameplay resolution, so its {@link GameSession}
     * is recorded as {@link SessionStatus#ABORTED} rather than
     * {@link SessionStatus#COMPLETED} — this is the only place either
     * status is ever assigned, and previously every match end was recorded
     * as {@code COMPLETED} regardless, making an abandoned match
     * indistinguishable from a cleanly declared one in the data.
     */
    @Async("gamePersistenceExecutor")
    @Transactional
    public void recordMatchEnd(String roomCode, Long winnerUserId, Map<Long, Integer> finalScores) {
        gameRoomRepository.findByRoomCode(roomCode).ifPresent(room -> {
            room.setStatus(RoomStatus.COMPLETED);
            gameRoomRepository.save(room);

            gameSessionRepository.findFirstByGameRoomIdOrderByStartedAtDesc(room.getId()).ifPresent(session -> {
                session.setStatus(winnerUserId != null ? SessionStatus.COMPLETED : SessionStatus.ABORTED);
                session.setEndedAt(Instant.now());
                if (winnerUserId != null) {
                    userRepository.findById(winnerUserId).ifPresent(session::setWinner);
                }
                gameSessionRepository.save(session);

                if (session.getStatus() == SessionStatus.COMPLETED) {
                    recentPlayersPort.recordEncounters(
                            finalScores.keySet(),
                            room.getId(),
                            room.getRoomCode(),
                            session.getEndedAt()
                    );
                }
            });

            finalScores.forEach((userId, score) ->
                    roomPlayerRepository.findByGameRoomIdAndUserId(room.getId(), userId).ifPresent(roomPlayer -> {
                        roomPlayer.setScore(score);
                        roomPlayerRepository.save(roomPlayer);
                    }));
        });
    }
}
