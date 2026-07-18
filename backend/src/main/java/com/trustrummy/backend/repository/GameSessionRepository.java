package com.trustrummy.backend.repository;

import com.trustrummy.backend.entity.GameSession;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface GameSessionRepository extends JpaRepository<GameSession, Long> {

    List<GameSession> findByGameRoomId(Long roomId);

    Optional<GameSession> findFirstByGameRoomIdOrderByStartedAtDesc(Long roomId);

    /**
     * {@code gameRoom}/{@code winner} are lazy and {@code open-in-view=false},
     * so history DTO builders (which run after this call's transaction has
     * already closed) need them already materialized — hence the fetch
     * joins rather than the plain {@code findById}. {@code winner} is
     * nullable (no winner yet / a draw), so it must be a LEFT JOIN.
     */
    @Query("SELECT gs FROM GameSession gs JOIN FETCH gs.gameRoom LEFT JOIN FETCH gs.winner WHERE gs.id = :id")
    Optional<GameSession> findWithDetailsById(@Param("id") Long id);

    /** Every session for a room this user was ever seated in — the "my match history" source query. */
    @Query("SELECT gs FROM GameSession gs JOIN RoomPlayer rp ON rp.gameRoom = gs.gameRoom "
            + "JOIN FETCH gs.gameRoom LEFT JOIN FETCH gs.winner "
            + "WHERE rp.user.id = :userId ORDER BY gs.startedAt DESC")
    Page<GameSession> findByParticipantUserId(@Param("userId") Long userId, Pageable pageable);
}
