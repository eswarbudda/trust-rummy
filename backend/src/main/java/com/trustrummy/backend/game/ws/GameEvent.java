package com.trustrummy.backend.game.ws;

import com.fasterxml.jackson.annotation.JsonAnyGetter;
import com.fasterxml.jackson.annotation.JsonProperty;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Fluent outbound event envelope. Serializes as a flat JSON object, e.g.
 * {@code GameEvent.of(EventType.TURN_STATE).with("currentTurnUserId", 7)}
 * becomes {@code {"type":"TURN_STATE","currentTurnUserId":7}}.
 */
public final class GameEvent {

    private final EventType type;
    private final Map<String, Object> fields = new LinkedHashMap<>();

    private GameEvent(EventType type) {
        this.type = type;
    }

    public static GameEvent of(EventType type) {
        return new GameEvent(type);
    }

    public GameEvent with(String key, Object value) {
        fields.put(key, value);
        return this;
    }

    @JsonProperty("type")
    public String getType() {
        return type.name();
    }

    @JsonAnyGetter
    public Map<String, Object> getFields() {
        return fields;
    }
}
