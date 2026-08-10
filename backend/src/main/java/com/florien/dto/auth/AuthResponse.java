package com.florien.dto.auth;

import java.util.UUID;

public record AuthResponse(
        String token,
        UUID userId,
        String email,
        String displayName,
        String avatarColor
) {}
