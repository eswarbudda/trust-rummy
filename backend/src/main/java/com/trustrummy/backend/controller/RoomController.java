package com.trustrummy.backend.controller;

import com.trustrummy.backend.dto.RoomCreateRequest;
import com.trustrummy.backend.dto.RoomReadyRequest;
import com.trustrummy.backend.dto.RoomResponse;
import com.trustrummy.backend.entity.GameRoom;
import com.trustrummy.backend.entity.RoomPlayer;
import com.trustrummy.backend.entity.RoomVisibility;
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
        // GROUP_ONLY + sourceGroupId are reserved for play-group start (RoomPort).
        if (request.getVisibility() == RoomVisibility.GROUP_ONLY || request.getSourceGroupId() != null) {
            throw new IllegalArgumentException("GROUP_ONLY rooms must be created via a play group");
        }
        if (request.getVisibility() == null) {
            request.setVisibility(RoomVisibility.PUBLIC);
        }
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

    /** Room detail incl. seated players — lets a client poll/refresh lobby state without going through the WebSocket. */
    @GetMapping("/{roomCode}")
    public ResponseEntity<RoomResponse> getRoom(@PathVariable String roomCode) {
        GameRoom room = roomService.getRoomByCode(roomCode);
        List<RoomPlayer> seated = roomService.getSeatedPlayers(room.getId());
        return ResponseEntity.ok(RoomResponse.from(room, seated));
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

    /** Un-seats the caller from a room that hasn't started yet. If the host leaves, the room is disbanded. */
    @PostMapping("/{roomCode}/leave")
    public ResponseEntity<Void> leaveRoom(
            @AuthenticationPrincipal UserDetails principal,
            @PathVariable String roomCode
    ) {
        roomService.leaveRoom(principal.getUsername(), roomCode);
        return ResponseEntity.noContent().build();
    }

    /** Host-only: closes a still-waiting room. */
    @DeleteMapping("/{roomCode}")
    public ResponseEntity<Void> cancelRoom(
            @AuthenticationPrincipal UserDetails principal,
            @PathVariable String roomCode
    ) {
        roomService.cancelRoom(principal.getUsername(), roomCode);
        return ResponseEntity.noContent().build();
    }

    /** Toggles the caller's ready flag in the lobby. */
    @PutMapping("/{roomCode}/ready")
    public ResponseEntity<RoomResponse> setReady(
            @AuthenticationPrincipal UserDetails principal,
            @PathVariable String roomCode,
            @RequestBody RoomReadyRequest request
    ) {
        GameRoom room = roomService.setReady(principal.getUsername(), roomCode, request.isReady());
        List<RoomPlayer> seated = roomService.getSeatedPlayers(room.getId());
        return ResponseEntity.ok(RoomResponse.from(room, seated));
    }
}
