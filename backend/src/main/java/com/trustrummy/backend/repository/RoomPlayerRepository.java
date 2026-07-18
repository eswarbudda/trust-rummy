package com.trustrummy.backend.repository;

import com.trustrummy.backend.entity.PlayerStatus;
import com.trustrummy.backend.entity.RoomPlayer;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface RoomPlayerRepository extends JpaRepository<RoomPlayer, Long> {

    /**
     * {@code RoomPlayer.user} is lazy and {@code spring.jpa.open-in-view=false},
     * so every caller that reads {@code .getUser().getUsername()} — DTO
     * builders in controllers/services running outside this call's own
     * transaction — needs {@code user} already materialized, not a proxy.
     * Hence the {@code JOIN FETCH} below rather than a plain derived query.
     */
    @Query("SELECT rp FROM RoomPlayer rp JOIN FETCH rp.user WHERE rp.gameRoom.id = :roomId")
    List<RoomPlayer> findByGameRoomId(@Param("roomId") Long roomId);

    Optional<RoomPlayer> findByGameRoomIdAndUserId(Long roomId, Long userId);

    /** Excludes players who have {@code LEFT} — the "currently seated" view used for capacity checks and match start. */
    @Query("SELECT rp FROM RoomPlayer rp JOIN FETCH rp.user WHERE rp.gameRoom.id = :roomId AND rp.status <> :status")
    List<RoomPlayer> findByGameRoomIdAndStatusNot(@Param("roomId") Long roomId, @Param("status") PlayerStatus status);
}
