package com.trustrummy.backend.controller;

import com.trustrummy.backend.dto.RoomCreateRequest;
import com.trustrummy.backend.dto.RoomResponse;
import com.trustrummy.backend.entity.GameRoom;
import com.trustrummy.backend.entity.RoomPlayer;
import com.trustrummy.backend.service.RoomService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/rooms")
@RequiredArgsConstructor
public class RoomController {

    private final RoomService roomService;

    @PostMapping
    public ResponseEntity<RoomResponse> createRoom(
            @AuthenticationPrincipal UserDetails principal,
            @Valid @RequestBody RoomCreateRequest request
    ) {
        GameRoom room = roomService.createRoom(principal.getUsername(), request);
        List<RoomPlayer> seated = roomService.getSeatedPlayers(room.getId());
        return ResponseEntity.ok(RoomResponse.from(room, seated));
    }

    @GetMapping
    public ResponseEntity<List<RoomResponse>> listOpenRooms() {
        List<RoomResponse> rooms = roomService.listOpenRooms().stream()
                .map(RoomResponse::from)
                .toList();
        return ResponseEntity.ok(rooms);
    }

    /**
     * Seats the authenticated user into an existing room. Required before
     * that user's WebSocket connection to {@code /ws/game/{roomCode}} counts
     * as a "seated player" for {@code START_MATCH} purposes.
     */
    @PostMapping("/{roomCode}/join")
    public ResponseEntity<RoomResponse> joinRoom(
            @AuthenticationPrincipal UserDetails principal,
            @PathVariable String roomCode
    ) {
        GameRoom room = roomService.joinRoom(principal.getUsername(), roomCode);
        List<RoomPlayer> seated = roomService.getSeatedPlayers(room.getId());
        return ResponseEntity.ok(RoomResponse.from(room, seated));
    }
}
