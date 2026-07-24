package com.trustrummy.backend.rooms;

/**
 * Active play-group membership check for {@code GROUP_ONLY} rooms.
 * Implemented in the playgroups module against membership rows only.
 */
public interface GroupRoomAccessPort {

    boolean isActiveMember(long groupId, long userId);
}
