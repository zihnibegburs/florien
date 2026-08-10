package com.florien.dto.auth;

import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record UpdateProfileRequest(
        @Size(min = 1, max = 100) String displayName,
        @Pattern(regexp = "^#[0-9A-Fa-f]{6}$") String avatarColor
) {}
