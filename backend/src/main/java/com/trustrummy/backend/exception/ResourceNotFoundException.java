package com.trustrummy.backend.exception;

/** Thrown when a referenced resource (room, session, etc.) does not exist. Maps to HTTP 404. */
public class ResourceNotFoundException extends RuntimeException {
    public ResourceNotFoundException(String message) {
        super(message);
    }
}
