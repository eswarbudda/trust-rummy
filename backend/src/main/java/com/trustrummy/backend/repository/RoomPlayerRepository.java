package com.trustrummy.backend.repository;

import com.trustrummy.backend.entity.RoomPlayer;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface RoomPlayerRepository extends JpaRepository<RoomPlayer, Long> {

    List<RoomPlayer> findByGameRoomId(Long roomId);

    Optional<RoomPlayer> findByGameRoomIdAndUserId(Long roomId, Long userId);
}
