package com.trustrummy.backend.repository;

import com.trustrummy.backend.entity.PlayerStatus;
import com.trustrummy.backend.entity.RoomPlayer;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface RoomPlayerRepository extends JpaRepository<RoomPlayer, Long> {

    List<RoomPlayer> findByGameRoomId(Long roomId);

    Optional<RoomPlayer> findByGameRoomIdAndUserId(Long roomId, Long userId);

    /** Excludes players who have {@code LEFT} — the "currently seated" view used for capacity checks and match start. */
    List<RoomPlayer> findByGameRoomIdAndStatusNot(Long roomId, PlayerStatus status);
}
