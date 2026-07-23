package com.trustrummy.backend.rooms;

import com.trustrummy.backend.dto.RoomCreateRequest;
import com.trustrummy.backend.entity.GameRoom;
import com.trustrummy.backend.entity.User;
import com.trustrummy.backend.exception.ResourceNotFoundException;
import com.trustrummy.backend.repository.GameRoomRepository;
import com.trustrummy.backend.service.RoomService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

@Component
@RequiredArgsConstructor
public class RoomPortAdapter implements RoomPort {

    private final RoomService roomService;
    private final GameRoomRepository gameRoomRepository;

    @Override
    @Transactional
    public RoomSummary createWaitingRoom(String creatorUsername, CreateWaitingRoomCommand command) {
        RoomCreateRequest request = new RoomCreateRequest();
        request.setName(command.name());
        request.setMaxPlayers(command.maxPlayers());
        request.setStakeAmount(command.stakeAmount());
        request.setGameType(command.gameType());
        request.setGameVariant(command.gameVariant());
        request.setDealsPerMatch(command.dealsPerMatch());
        return toSummary(roomService.createRoom(creatorUsername, request));
    }

    @Override
    @Transactional
    public RoomSummary joinRoom(String username, String roomCode) {
        return toSummary(roomService.joinRoom(username, roomCode));
    }

    @Override
    @Transactional(readOnly = true)
    public RoomSummary requireByCode(String roomCode) {
        GameRoom room = roomService.getRoomByCode(roomCode);
        if (room.getCreatedBy() != null) {
            room.getCreatedBy().getUsername();
        }
        return toSummary(room);
    }

    @Override
    @Transactional(readOnly = true)
    public RoomSummary requireById(long roomId) {
        GameRoom room = gameRoomRepository.findById(roomId)
                .orElseThrow(() -> new ResourceNotFoundException("Room not found"));
        // Touch lazy association while session is open.
        if (room.getCreatedBy() != null) {
            room.getCreatedBy().getUsername();
        }
        return toSummary(room);
    }

    private static RoomSummary toSummary(GameRoom room) {
        User creator = room.getCreatedBy();
        if (creator == null || creator.getId() == null) {
            throw new IllegalStateException("Room has no creator");
        }
        return new RoomSummary(
                room.getId(),
                room.getRoomCode(),
                room.getStatus().name(),
                creator.getId(),
                creator.getUsername(),
                room.getMaxPlayers() != null ? room.getMaxPlayers() : 6,
                room.getName()
        );
    }
}
