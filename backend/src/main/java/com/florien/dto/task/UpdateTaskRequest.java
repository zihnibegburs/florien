package com.florien.dto.task;

import com.florien.domain.enums.TaskStatus;

import java.time.Instant;
import java.util.UUID;

public record UpdateTaskRequest(
        String title,
        String description,
        String color,
        String icon,
        Integer durationMinutes,
        Instant scheduledAt,
        TaskStatus status,
        Integer sortOrder,
        Boolean isInbox,
        String reward,
        String energyLevel,
        String motivation,
        Integer transitionBufferMinutes
) {}
