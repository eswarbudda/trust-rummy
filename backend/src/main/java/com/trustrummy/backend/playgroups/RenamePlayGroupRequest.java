package com.trustrummy.backend.playgroups;

import jakarta.validation.constraints.AssertTrue;
import jakarta.validation.constraints.Size;

public record RenamePlayGroupRequest(
        @Size(max = 64) String name
) {
    @AssertTrue(message = "name is required")
    public boolean isNamePresent() {
        return name != null && !name.isBlank();
    }
}
