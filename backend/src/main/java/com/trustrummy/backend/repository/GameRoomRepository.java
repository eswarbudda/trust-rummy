package com.trustrummy.backend.repository;

import com.trustrummy.backend.entity.GameRoom;
import com.trustrummy.backend.entity.RoomStatus;
import com.trustrummy.backend.entity.RoomVisibility;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface GameRoomRepository extends JpaRepository<GameRoom, Long> {

    Optional<GameRoom> findByRoomCode(String roomCode);

    List<GameRoom> findByStatus(RoomStatus status);

    List<GameRoom> findByStatusAndVisibility(RoomStatus status, RoomVisibility visibility);
}
