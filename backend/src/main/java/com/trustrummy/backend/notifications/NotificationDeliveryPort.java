package com.trustrummy.backend.notifications;

/**
 * Pluggable delivery after persist. MVP: WebSocket. Future: push/email adapters.
 */
public interface NotificationDeliveryPort {

    void deliver(NotificationView notification);
}
