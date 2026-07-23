package com.trustrummy.backend.playgroups;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record CreatePlayGroupRequest(
        @NotBlank @Size(max = 64) String name,
        Integer maxMembers
) {
}
