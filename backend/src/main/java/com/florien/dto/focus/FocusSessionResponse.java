package com.florien.dto.focus;

import com.florien.domain.enums.TaskStatus;

import java.time.Instant;
import java.util.UUID;

public record FocusSessionResponse(
        UUID taskId,
        String title,
        String color,
        int durationMinutes,
        TaskStatus status,
        Instant startedAt,
        long elapsedSeconds,
        long remainingSeconds,
        double progressPercent
) {}
