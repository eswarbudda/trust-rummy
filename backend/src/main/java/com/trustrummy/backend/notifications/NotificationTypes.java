package com.trustrummy.backend.notifications;

/**
 * Extensible notification type catalog. MVP producers use
 * {@link #FRIEND_REQUEST}, {@link #FRIEND_ACCEPTED}, {@link #ROOM_INVITATION},
 * and {@link #GROUP_INVITATION}; others are reserved for future modules.
 */
public final class NotificationTypes {
    public static final String FRIEND_REQUEST = "FRIEND_REQUEST";
    public static final String FRIEND_ACCEPTED = "FRIEND_ACCEPTED";
    public static final String ROOM_INVITATION = "ROOM_INVITATION";
    public static final String GROUP_INVITATION = "GROUP_INVITATION";
    public static final String TOURNAMENT_INVITATION = "TOURNAMENT_INVITATION";
    public static final String WALLET_DEPOSIT_SUCCESS = "WALLET_DEPOSIT_SUCCESS";
    public static final String WALLET_WITHDRAWAL_SUCCESS = "WALLET_WITHDRAWAL_SUCCESS";
    public static final String DAILY_BONUS = "DAILY_BONUS";
    public static final String FRIEND_ONLINE = "FRIEND_ONLINE";
    public static final String ADMIN_BROADCAST = "ADMIN_BROADCAST";

    private NotificationTypes() {
    }
}
