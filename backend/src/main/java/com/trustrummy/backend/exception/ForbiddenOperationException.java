package com.trustrummy.backend.exception;

/** Thrown when an authenticated user attempts an action they don't have rights to (e.g. non-host cancelling a room). Maps to HTTP 403. */
public class ForbiddenOperationException extends RuntimeException {
    public ForbiddenOperationException(String message) {
        super(message);
    }
}
