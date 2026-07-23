package com.trustrummy.backend.rooms;

/**
 * Port for social modules to create/join waiting rooms without importing room repositories.
 */
public interface RoomPort {

    RoomSummary createWaitingRoom(String creatorUsername, CreateWaitingRoomCommand command);

    RoomSummary joinRoom(String username, String roomCode);

    RoomSummary requireByCode(String roomCode);

    RoomSummary requireById(long roomId);
}
