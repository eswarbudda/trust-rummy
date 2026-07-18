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

    /** Every session for a room this user was ever seated in — the "my match history" source query. */
    @Query("SELECT gs FROM GameSession gs JOIN RoomPlayer rp ON rp.gameRoom = gs.gameRoom "
            + "WHERE rp.user.id = :userId ORDER BY gs.startedAt DESC")
    Page<GameSession> findByParticipantUserId(@Param("userId") Long userId, Pageable pageable);
}
