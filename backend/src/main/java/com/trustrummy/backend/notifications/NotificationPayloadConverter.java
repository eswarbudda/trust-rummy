package com.trustrummy.backend.notifications;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.persistence.AttributeConverter;
import jakarta.persistence.Converter;

import java.util.HashMap;
import java.util.Map;

@Converter
public class NotificationPayloadConverter implements AttributeConverter<Map<String, Object>, String> {

    private static final ObjectMapper MAPPER = new ObjectMapper();
    private static final TypeReference<Map<String, Object>> TYPE = new TypeReference<>() {
    };

    @Override
    public String convertToDatabaseColumn(Map<String, Object> attribute) {
        try {
            return MAPPER.writeValueAsString(attribute == null ? Map.of() : attribute);
        } catch (Exception ex) {
            throw new IllegalStateException("Failed to serialize notification payload", ex);
        }
    }

    @Override
    public Map<String, Object> convertToEntityAttribute(String dbData) {
        if (dbData == null || dbData.isBlank()) {
            return new HashMap<>();
        }
        try {
            return new HashMap<>(MAPPER.readValue(dbData, TYPE));
        } catch (Exception ex) {
            throw new IllegalStateException("Failed to deserialize notification payload", ex);
        }
    }
}
